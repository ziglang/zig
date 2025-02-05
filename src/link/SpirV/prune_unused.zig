//! This pass is used to simple pruning of unused things:
//! - Instructions at global scope
//! - Functions
//! Debug info and nonsemantic instructions are not handled;
//! this pass is mainly intended for cleaning up left over
//! stuff from codegen and other passes that is generated
//! but not actually used.

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const log = std.log.scoped(.spirv_link);

const BinaryModule = @import("BinaryModule.zig");
const Section = @import("../../codegen/spirv/Section.zig");
const spec = @import("../../codegen/spirv/spec.zig");
const Opcode = spec.Opcode;
const ResultId = spec.IdResult;
const Word = spec.Word;

/// Return whether a particular opcode's instruction can be pruned.
/// These are idempotent instructions at globals scope and instructions
/// within functions that do not have any side effects.
/// The opcodes that return true here do not necessarily need to
/// have an .IdResult. If they don't, then they are regarded
/// as 'decoration'-style instructions that don't keep their
/// operands alive, but will be emitted if they are.
fn canPrune(op: Opcode) bool {
    // This list should be as worked out as possible, but just
    // getting common instructions is a good effort/effect ratio.
    // When adding items to this list, also check whether the
    // instruction requires any special control flow rules (like
    // with labels and control flow and stuff) and whether the
    // instruction has any non-trivial side effects (like OpLoad
    // with the Volatile memory semantics).
    return switch (op.class()) {
        .TypeDeclaration,
        .Conversion,
        .Arithmetic,
        .RelationalAndLogical,
        .Bit,
        => true,
        else => switch (op) {
            .OpFunction,
            .OpUndef,
            .OpString,
            .OpName,
            .OpMemberName,
            // Prune OpConstant* instructions but
            // retain OpSpecConstant declaration instructions
            .OpConstantTrue,
            .OpConstantFalse,
            .OpConstant,
            .OpConstantComposite,
            .OpConstantSampler,
            .OpConstantNull,
            .OpSpecConstantOp,
            // Prune ext inst import instructions, but not
            // ext inst instructions themselves, because
            // we don't know if they might have side effects.
            .OpExtInstImport,
            => true,
            else => false,
        },
    };
}

const ModuleInfo = struct {
    const Fn = struct {
        /// The index of the first callee in `callee_store`.
        first_callee: usize,
    };

    /// Maps function result-id -> Fn information structure.
    functions: std.AutoArrayHashMapUnmanaged(ResultId, Fn),
    /// For each function, a list of function result-ids that it calls.
    callee_store: []const ResultId,
    /// For each instruction, the offset at which it appears in the source module.
    result_id_to_code_offset: std.AutoArrayHashMapUnmanaged(ResultId, usize),

    /// Fetch the list of callees per function. Guaranteed to contain only unique IDs.
    fn callees(self: ModuleInfo, fn_id: ResultId) []const ResultId {
        const fn_index = self.functions.getIndex(fn_id).?;
        const values = self.functions.values();
        const first_callee = values[fn_index].first_callee;
        if (fn_index == values.len - 1) {
            return self.callee_store[first_callee..];
        } else {
            const next_first_callee = values[fn_index + 1].first_callee;
            return self.callee_store[first_callee..next_first_callee];
        }
    }

    /// Extract the information required to run this pass from the binary.
    // TODO: Should the contents of this function be merged with that of lower_invocation_globals.zig?
    // Many of the contents are the same...
    fn parse(
        arena: Allocator,
        parser: *BinaryModule.Parser,
        binary: BinaryModule,
    ) !ModuleInfo {
        var functions = std.AutoArrayHashMap(ResultId, Fn).init(arena);
        var calls = std.AutoArrayHashMap(ResultId, void).init(arena);
        var callee_store = std.ArrayList(ResultId).init(arena);
        var result_id_to_code_offset = std.AutoArrayHashMap(ResultId, usize).init(arena);
        var maybe_current_function: ?ResultId = null;
        var it = binary.iterateInstructions();
        while (it.next()) |inst| {
            const inst_spec = parser.getInstSpec(inst.opcode).?;

            // Result-id can only be the first or second operand
            const maybe_result_id: ?ResultId = for (0..2) |i| {
                if (inst_spec.operands.len > i and inst_spec.operands[i].kind == .IdResult) {
                    break @enumFromInt(inst.operands[i]);
                }
            } else null;

            // Only add result-ids of functions and anything outside a function.
            // Result-ids declared inside functions cannot be reached outside anyway,
            // and we don't care about the internals of functions anyway.
            // Note that in the case of OpFunction, `maybe_current_function` is
            // also `null`, because it is set below.
            if (maybe_result_id) |result_id| {
                try result_id_to_code_offset.put(result_id, inst.offset);
            }

            switch (inst.opcode) {
                .OpFunction => {
                    if (maybe_current_function) |current_function| {
                        log.err("OpFunction {} does not have an OpFunctionEnd", .{current_function});
                        return error.InvalidPhysicalFormat;
                    }

                    maybe_current_function = @enumFromInt(inst.operands[1]);
                },
                .OpFunctionCall => {
                    const callee: ResultId = @enumFromInt(inst.operands[2]);
                    try calls.put(callee, {});
                },
                .OpFunctionEnd => {
                    const current_function = maybe_current_function orelse {
                        log.err("encountered OpFunctionEnd without corresponding OpFunction", .{});
                        return error.InvalidPhysicalFormat;
                    };
                    const entry = try functions.getOrPut(current_function);
                    if (entry.found_existing) {
                        log.err("Function {} has duplicate definition", .{current_function});
                        return error.DuplicateId;
                    }

                    const first_callee = callee_store.items.len;
                    try callee_store.appendSlice(calls.keys());

                    entry.value_ptr.* = .{
                        .first_callee = first_callee,
                    };
                    maybe_current_function = null;
                    calls.clearRetainingCapacity();
                },
                else => {},
            }
        }

        if (maybe_current_function) |current_function| {
            log.err("OpFunction {} does not have an OpFunctionEnd", .{current_function});
            return error.InvalidPhysicalFormat;
        }

        return ModuleInfo{
            .functions = functions.unmanaged,
            .callee_store = callee_store.items,
            .result_id_to_code_offset = result_id_to_code_offset.unmanaged,
        };
    }
};

const AliveMarker = struct {
    parser: *BinaryModule.Parser,
    binary: BinaryModule,
    info: ModuleInfo,
    result_id_offsets: std.ArrayList(u16),
    alive: std.DynamicBitSetUnmanaged,

    fn markAlive(self: *AliveMarker, result_id: ResultId) BinaryModule.ParseError!void {
        const index = self.info.result_id_to_code_offset.getIndex(result_id) orelse {
            log.err("undefined result-id {}", .{result_id});
            return error.InvalidId;
        };

        if (self.alive.isSet(index)) {
            return;
        }
        self.alive.set(index);

        const offset = self.info.result_id_to_code_offset.values()[index];
        const inst = self.binary.instructionAt(offset);

        if (inst.opcode == .OpFunction) {
            try self.markFunctionAlive(inst);
        } else {
            try self.markInstructionAlive(inst);
        }
    }

    fn markFunctionAlive(
        self: *AliveMarker,
        func_inst: BinaryModule.Instruction,
    ) !void {
        // Go through the instruction and mark the
        // operands of each instruction alive.
        var it = self.binary.iterateInstructionsFrom(func_inst.offset);
        try self.markInstructionAlive(it.next().?);
        while (it.next()) |inst| {
            if (inst.opcode == .OpFunctionEnd) {
                break;
            }

            if (!canPrune(inst.opcode)) {
                try self.markInstructionAlive(inst);
            }
        }
    }

    fn markInstructionAlive(
        self: *AliveMarker,
        inst: BinaryModule.Instruction,
    ) !void {
        const start_offset = self.result_id_offsets.items.len;
        try self.parser.parseInstructionResultIds(self.binary, inst, &self.result_id_offsets);
        const end_offset = self.result_id_offsets.items.len;

        // Recursive calls to markInstructionAlive() might change the pointer in self.result_id_offsets,
        // so we need to iterate it manually.
        var i = start_offset;
        while (i < end_offset) : (i += 1) {
            const offset = self.result_id_offsets.items[i];
            try self.markAlive(@enumFromInt(inst.operands[offset]));
        }
    }
};

fn removeIdsFromMap(a: Allocator, map: anytype, info: ModuleInfo, alive_marker: AliveMarker) !void {
    var to_remove = std.ArrayList(ResultId).init(a);
    var it = map.iterator();
    while (it.next()) |entry| {
        const id = entry.key_ptr.*;
        const index = info.result_id_to_code_offset.getIndex(id).?;
        if (!alive_marker.alive.isSet(index)) {
            try to_remove.append(id);
        }
    }

    for (to_remove.items) |id| {
        assert(map.remove(id));
    }
}

pub fn run(parser: *BinaryModule.Parser, binary: *BinaryModule, progress: std.Progress.Node) !void {
    const sub_node = progress.start("Prune unused IDs", 0);
    defer sub_node.end();

    var arena = std.heap.ArenaAllocator.init(parser.a);
    defer arena.deinit();
    const a = arena.allocator();

    const info = try ModuleInfo.parse(a, parser, binary.*);

    var alive_marker = AliveMarker{
        .parser = parser,
        .binary = binary.*,
        .info = info,
        .result_id_offsets = std.ArrayList(u16).init(a),
        .alive = try std.DynamicBitSetUnmanaged.initEmpty(a, info.result_id_to_code_offset.count()),
    };

    // Mark initial stuff as slive
    {
        var it = binary.iterateInstructions();
        while (it.next()) |inst| {
            if (inst.opcode == .OpFunction) {
                // No need to process further.
                break;
            } else if (!canPrune(inst.opcode)) {
                try alive_marker.markInstructionAlive(inst);
            }
        }
    }

    var section = Section{};

    sub_node.setEstimatedTotalItems(binary.instructions.len);

    var new_functions_section: ?usize = null;
    var it = binary.iterateInstructions();
    skip: while (it.next()) |inst| {
        defer sub_node.setCompletedItems(inst.offset);

        const inst_spec = parser.getInstSpec(inst.opcode).?;

        reemit: {
            if (!canPrune(inst.opcode)) {
                break :reemit;
            }

            // Result-id can only be the first or second operand
            const result_id: ResultId = for (0..2) |i| {
                if (inst_spec.operands.len > i and inst_spec.operands[i].kind == .IdResult) {
                    break @enumFromInt(inst.operands[i]);
                }
            } else {
                // Instruction can be pruned but doesn't have a result id.
                // Check all operands to see if they are alive, and emit it only if so.
                alive_marker.result_id_offsets.items.len = 0;
                try parser.parseInstructionResultIds(binary.*, inst, &alive_marker.result_id_offsets);
                for (alive_marker.result_id_offsets.items) |offset| {
                    const id: ResultId = @enumFromInt(inst.operands[offset]);
                    const index = info.result_id_to_code_offset.getIndex(id).?;

                    if (!alive_marker.alive.isSet(index)) {
                        continue :skip;
                    }
                }

                break :reemit;
            };

            const index = info.result_id_to_code_offset.getIndex(result_id).?;
            if (alive_marker.alive.isSet(index)) {
                break :reemit;
            }

            if (inst.opcode != .OpFunction) {
                // Instruction can be pruned and its not alive, so skip it.
                continue :skip;
            }

            // We're at the start of a function that can be pruned, so skip everything until
            // we encounter an OpFunctionEnd.
            while (it.next()) |body_inst| {
                if (body_inst.opcode == .OpFunctionEnd)
                    break;
            }

            continue :skip;
        }

        if (inst.opcode == .OpFunction and new_functions_section == null) {
            new_functions_section = section.instructions.items.len;
        }

        try section.emitRawInstruction(a, inst.opcode, inst.operands);
    }

    // This pass might have pruned ext inst imports or arith types, update
    // those maps to main consistency.
    try removeIdsFromMap(a, &binary.ext_inst_map, info, alive_marker);
    try removeIdsFromMap(a, &binary.arith_type_width, info, alive_marker);

    binary.instructions = try parser.a.dupe(Word, section.toWords());
    binary.sections.functions = new_functions_section orelse binary.instructions.len;
}
