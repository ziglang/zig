const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const CodeGen = @import("CodeGen.zig");
const Decl = @import("Module.zig").Decl;

const spec = @import("spec.zig");
const Opcode = spec.Opcode;
const Word = spec.Word;
const Id = spec.Id;
const StorageClass = spec.StorageClass;

const Assembler = @This();

cg: *CodeGen,
errors: std.ArrayListUnmanaged(ErrorMsg) = .empty,
src: []const u8 = undefined,
/// `ass.src` tokenized.
tokens: std.ArrayListUnmanaged(Token) = .empty,
current_token: u32 = 0,
/// The instruction that is currently being parsed or has just been parsed.
inst: struct {
    opcode: Opcode = undefined,
    operands: std.ArrayListUnmanaged(Operand) = .empty,
    string_bytes: std.ArrayListUnmanaged(u8) = .empty,

    fn result(ass: @This()) ?AsmValue.Ref {
        for (ass.operands.items[0..@min(ass.operands.items.len, 2)]) |op| {
            switch (op) {
                .result_id => |index| return index,
                else => {},
            }
        }
        return null;
    }
} = .{},
value_map: std.StringArrayHashMapUnmanaged(AsmValue) = .{},
inst_map: std.StringArrayHashMapUnmanaged(void) = .empty,

const Operand = union(enum) {
    /// Any 'simple' 32-bit value. This could be a mask or
    /// enumerant, etc, depending on the operands.
    value: u32,
    /// An int- or float literal encoded as 1 word.
    literal32: u32,
    /// An int- or float literal encoded as 2 words.
    literal64: u64,
    /// A result-id which is assigned to in this instruction.
    /// If present, this is the first operand of the instruction.
    result_id: AsmValue.Ref,
    /// A result-id which referred to (not assigned to) in this instruction.
    ref_id: AsmValue.Ref,
    /// Offset into `inst.string_bytes`. The string ends at the next zero-terminator.
    string: u32,
};

pub fn deinit(ass: *Assembler) void {
    const gpa = ass.cg.module.gpa;
    for (ass.errors.items) |err| gpa.free(err.msg);
    ass.tokens.deinit(gpa);
    ass.errors.deinit(gpa);
    ass.inst.operands.deinit(gpa);
    ass.inst.string_bytes.deinit(gpa);
    ass.value_map.deinit(gpa);
    ass.inst_map.deinit(gpa);
}

const Error = error{ AssembleFail, OutOfMemory };

pub fn assemble(ass: *Assembler, src: []const u8) Error!void {
    const gpa = ass.cg.module.gpa;

    ass.src = src;
    ass.errors.clearRetainingCapacity();

    // Populate the opcode map if it isn't already
    if (ass.inst_map.count() == 0) {
        const instructions = spec.InstructionSet.core.instructions();
        try ass.inst_map.ensureUnusedCapacity(gpa, @intCast(instructions.len));
        for (spec.InstructionSet.core.instructions(), 0..) |inst, i| {
            const entry = try ass.inst_map.getOrPut(gpa, inst.name);
            assert(entry.index == i);
        }
    }

    try ass.tokenize();
    while (!ass.testToken(.eof)) {
        try ass.parseInstruction();
        try ass.processInstruction();
    }

    if (ass.errors.items.len > 0) return error.AssembleFail;
}

const ErrorMsg = struct {
    /// The offset in bytes from the start of `src` that this error occured.
    byte_offset: u32,
    msg: []const u8,
};

fn addError(ass: *Assembler, offset: u32, comptime fmt: []const u8, args: anytype) !void {
    const gpa = ass.cg.module.gpa;
    const msg = try std.fmt.allocPrint(gpa, fmt, args);
    errdefer gpa.free(msg);
    try ass.errors.append(gpa, .{
        .byte_offset = offset,
        .msg = msg,
    });
}

fn fail(ass: *Assembler, offset: u32, comptime fmt: []const u8, args: anytype) Error {
    try ass.addError(offset, fmt, args);
    return error.AssembleFail;
}

fn todo(ass: *Assembler, comptime fmt: []const u8, args: anytype) Error {
    return ass.fail(0, "todo: " ++ fmt, args);
}

const AsmValue = union(enum) {
    /// The results are stored in an array hash map, and can be referred
    /// to either by name (without the %), or by values of this index type.
    pub const Ref = u32;

    /// The RHS of the current instruction.
    just_declared,
    /// A placeholder for ref-ids of which the result-id is not yet known.
    /// It will be further resolved at a later stage to a more concrete forward reference.
    unresolved_forward_reference,
    /// A normal result produced by a different instruction.
    value: Id,
    /// A type registered into the module's type system.
    ty: Id,
    /// A pre-supplied constant integer value.
    constant: u32,
    string: []const u8,

    /// Retrieve the result-id of this AsmValue. Asserts that this AsmValue
    /// is of a variant that allows the result to be obtained (not an unresolved
    /// forward declaration, not in the process of being declared, etc).
    pub fn resultId(value: AsmValue) Id {
        return switch (value) {
            .just_declared,
            .unresolved_forward_reference,
            // TODO: Lower this value as constant?
            .constant,
            .string,
            => unreachable,
            .value => |result| result,
            .ty => |result| result,
        };
    }
};

/// Attempt to process the instruction currently in `ass.inst`.
/// This for example emits the instruction in the module or function, or
/// records type definitions.
/// If this function returns `error.AssembleFail`, an explanatory
/// error message has already been emitted into `ass.errors`.
fn processInstruction(ass: *Assembler) !void {
    const module = ass.cg.module;
    const result: AsmValue = switch (ass.inst.opcode) {
        .OpEntryPoint => {
            return ass.fail(ass.currentToken().start, "cannot export entry points in assembly", .{});
        },
        .OpExecutionMode, .OpExecutionModeId => {
            return ass.fail(ass.currentToken().start, "cannot set execution mode in assembly", .{});
        },
        .OpCapability => {
            try module.addCapability(@enumFromInt(ass.inst.operands.items[0].value));
            return;
        },
        .OpExtension => {
            const ext_name_offset = ass.inst.operands.items[0].string;
            const ext_name = std.mem.sliceTo(ass.inst.string_bytes.items[ext_name_offset..], 0);
            try module.addExtension(ext_name);
            return;
        },
        .OpExtInstImport => blk: {
            const set_name_offset = ass.inst.operands.items[1].string;
            const set_name = std.mem.sliceTo(ass.inst.string_bytes.items[set_name_offset..], 0);
            const set_tag = std.meta.stringToEnum(spec.InstructionSet, set_name) orelse {
                return ass.fail(set_name_offset, "unknown instruction set: {s}", .{set_name});
            };
            break :blk .{ .value = try module.importInstructionSet(set_tag) };
        },
        else => switch (ass.inst.opcode.class()) {
            .type_declaration => try ass.processTypeInstruction(),
            else => (try ass.processGenericInstruction()) orelse return,
        },
    };

    const result_ref = ass.inst.result().?;
    switch (ass.value_map.values()[result_ref]) {
        .just_declared => ass.value_map.values()[result_ref] = result,
        else => {
            // TODO: Improve source location.
            const name = ass.value_map.keys()[result_ref];
            return ass.fail(0, "duplicate definition of %{s}", .{name});
        },
    }
}

fn processTypeInstruction(ass: *Assembler) !AsmValue {
    const cg = ass.cg;
    const gpa = cg.module.gpa;
    const module = cg.module;
    const operands = ass.inst.operands.items;
    const section = &module.sections.globals;
    const id = switch (ass.inst.opcode) {
        .OpTypeVoid => try module.voidType(),
        .OpTypeBool => try module.boolType(),
        .OpTypeInt => blk: {
            const signedness: std.builtin.Signedness = switch (operands[2].literal32) {
                0 => .unsigned,
                1 => .signed,
                else => {
                    // TODO: Improve source location.
                    return ass.fail(0, "{} is not a valid signedness (expected 0 or 1)", .{operands[2].literal32});
                },
            };
            const width = std.math.cast(u16, operands[1].literal32) orelse {
                return ass.fail(0, "int type of {} bits is too large", .{operands[1].literal32});
            };
            break :blk try module.intType(signedness, width);
        },
        .OpTypeFloat => blk: {
            const bits = operands[1].literal32;
            switch (bits) {
                16, 32, 64 => {},
                else => {
                    return ass.fail(0, "{} is not a valid bit count for floats (expected 16, 32 or 64)", .{bits});
                },
            }
            break :blk try module.floatType(@intCast(bits));
        },
        .OpTypeVector => blk: {
            const child_type = try ass.resolveRefId(operands[1].ref_id);
            break :blk try module.vectorType(operands[2].literal32, child_type);
        },
        .OpTypeArray => {
            // TODO: The length of an OpTypeArray is determined by a constant (which may be a spec constant),
            // and so some consideration must be taken when entering this in the type system.
            return ass.todo("process OpTypeArray", .{});
        },
        .OpTypeRuntimeArray => blk: {
            const element_type = try ass.resolveRefId(operands[1].ref_id);
            const result_id = module.allocId();
            try section.emit(module.gpa, .OpTypeRuntimeArray, .{
                .id_result = result_id,
                .element_type = element_type,
            });
            break :blk result_id;
        },
        .OpTypePointer => blk: {
            const storage_class: StorageClass = @enumFromInt(operands[1].value);
            const child_type = try ass.resolveRefId(operands[2].ref_id);
            const result_id = module.allocId();
            try section.emit(module.gpa, .OpTypePointer, .{
                .id_result = result_id,
                .storage_class = storage_class,
                .type = child_type,
            });
            break :blk result_id;
        },
        .OpTypeStruct => blk: {
            const scratch_top = cg.id_scratch.items.len;
            defer cg.id_scratch.shrinkRetainingCapacity(scratch_top);
            const ids = try cg.id_scratch.addManyAsSlice(gpa, operands[1..].len);
            for (operands[1..], ids) |op, *id| id.* = try ass.resolveRefId(op.ref_id);
            break :blk try module.structType(ids, null, null, .none);
        },
        .OpTypeImage => blk: {
            const sampled_type = try ass.resolveRefId(operands[1].ref_id);
            const result_id = module.allocId();
            try section.emit(gpa, .OpTypeImage, .{
                .id_result = result_id,
                .sampled_type = sampled_type,
                .dim = @enumFromInt(operands[2].value),
                .depth = operands[3].literal32,
                .arrayed = operands[4].literal32,
                .ms = operands[5].literal32,
                .sampled = operands[6].literal32,
                .image_format = @enumFromInt(operands[7].value),
            });
            break :blk result_id;
        },
        .OpTypeSampler => blk: {
            const result_id = module.allocId();
            try section.emit(gpa, .OpTypeSampler, .{ .id_result = result_id });
            break :blk result_id;
        },
        .OpTypeSampledImage => blk: {
            const image_type = try ass.resolveRefId(operands[1].ref_id);
            const result_id = module.allocId();
            try section.emit(gpa, .OpTypeSampledImage, .{ .id_result = result_id, .image_type = image_type });
            break :blk result_id;
        },
        .OpTypeFunction => blk: {
            const param_operands = operands[2..];
            const return_type = try ass.resolveRefId(operands[1].ref_id);

            const scratch_top = cg.id_scratch.items.len;
            defer cg.id_scratch.shrinkRetainingCapacity(scratch_top);
            const param_types = try cg.id_scratch.addManyAsSlice(gpa, param_operands.len);

            for (param_types, param_operands) |*param, operand| {
                param.* = try ass.resolveRefId(operand.ref_id);
            }
            const result_id = module.allocId();
            try section.emit(module.gpa, .OpTypeFunction, .{
                .id_result = result_id,
                .return_type = return_type,
                .id_ref_2 = param_types,
            });
            break :blk result_id;
        },
        else => return ass.todo("process type instruction {s}", .{@tagName(ass.inst.opcode)}),
    };

    return .{ .ty = id };
}

/// - No forward references are allowed in operands.
/// - Target section is determined from instruction type.
fn processGenericInstruction(ass: *Assembler) !?AsmValue {
    const module = ass.cg.module;
    const target = module.zcu.getTarget();
    const operands = ass.inst.operands.items;
    var maybe_spv_decl_index: ?Decl.Index = null;
    const section = switch (ass.inst.opcode.class()) {
        .constant_creation => &module.sections.globals,
        .annotation => &module.sections.annotations,
        .type_declaration => unreachable, // Handled elsewhere.
        else => switch (ass.inst.opcode) {
            .OpEntryPoint => unreachable,
            .OpExecutionMode, .OpExecutionModeId => &module.sections.execution_modes,
            .OpVariable => section: {
                const storage_class: spec.StorageClass = @enumFromInt(operands[2].value);
                if (storage_class == .function) break :section &ass.cg.prologue;
                maybe_spv_decl_index = try module.allocDecl(.global);
                if (!target.cpu.has(.spirv, .v1_4) and storage_class != .input and storage_class != .output) {
                    // Before version 1.4, the interface’s storage classes are limited to the Input and Output
                    break :section &module.sections.globals;
                }
                try ass.cg.module.decl_deps.append(module.gpa, maybe_spv_decl_index.?);
                break :section &module.sections.globals;
            },
            else => &ass.cg.body,
        },
    };

    var maybe_result_id: ?Id = null;
    const first_word = section.instructions.items.len;
    // At this point we're not quite sure how many operands this instruction is
    // going to have, so insert 0 and patch up the actual opcode word later.
    try section.ensureUnusedCapacity(module.gpa, 1);
    section.writeWord(0);

    for (operands) |operand| {
        switch (operand) {
            .value, .literal32 => |word| {
                try section.ensureUnusedCapacity(module.gpa, 1);
                section.writeWord(word);
            },
            .literal64 => |dword| {
                try section.ensureUnusedCapacity(module.gpa, 2);
                section.writeDoubleWord(dword);
            },
            .result_id => {
                maybe_result_id = if (maybe_spv_decl_index) |spv_decl_index|
                    module.declPtr(spv_decl_index).result_id
                else
                    module.allocId();
                try section.ensureUnusedCapacity(module.gpa, 1);
                section.writeOperand(Id, maybe_result_id.?);
            },
            .ref_id => |index| {
                const result = try ass.resolveRef(index);
                try section.ensureUnusedCapacity(module.gpa, 1);
                section.writeOperand(spec.Id, result.resultId());
            },
            .string => |offset| {
                const text = std.mem.sliceTo(ass.inst.string_bytes.items[offset..], 0);
                const size = std.math.divCeil(usize, text.len + 1, @sizeOf(Word)) catch unreachable;
                try section.ensureUnusedCapacity(module.gpa, size);
                section.writeOperand(spec.LiteralString, text);
            },
        }
    }

    const actual_word_count = section.instructions.items.len - first_word;
    section.instructions.items[first_word] |= @as(u32, @as(u16, @intCast(actual_word_count))) << 16 | @intFromEnum(ass.inst.opcode);

    if (maybe_result_id) |result| return .{ .value = result };
    return null;
}

fn resolveMaybeForwardRef(ass: *Assembler, ref: AsmValue.Ref) !AsmValue {
    const value = ass.value_map.values()[ref];
    switch (value) {
        .just_declared => {
            const name = ass.value_map.keys()[ref];
            // TODO: Improve source location.
            return ass.fail(0, "ass-referential parameter %{s}", .{name});
        },
        else => return value,
    }
}

fn resolveRef(ass: *Assembler, ref: AsmValue.Ref) !AsmValue {
    const value = try ass.resolveMaybeForwardRef(ref);
    switch (value) {
        .just_declared => unreachable,
        .unresolved_forward_reference => {
            const name = ass.value_map.keys()[ref];
            // TODO: Improve source location.
            return ass.fail(0, "reference to undeclared result-id %{s}", .{name});
        },
        else => return value,
    }
}

fn resolveRefId(ass: *Assembler, ref: AsmValue.Ref) !Id {
    const value = try ass.resolveRef(ref);
    return value.resultId();
}

fn parseInstruction(ass: *Assembler) !void {
    const gpa = ass.cg.module.gpa;

    ass.inst.opcode = undefined;
    ass.inst.operands.clearRetainingCapacity();
    ass.inst.string_bytes.clearRetainingCapacity();

    const lhs_result_tok = ass.currentToken();
    const maybe_lhs_result: ?AsmValue.Ref = if (ass.eatToken(.result_id_assign)) blk: {
        const name = ass.tokenText(lhs_result_tok)[1..];
        const entry = try ass.value_map.getOrPut(gpa, name);
        try ass.expectToken(.equals);
        if (!entry.found_existing) {
            entry.value_ptr.* = .just_declared;
        }
        break :blk @intCast(entry.index);
    } else null;

    const opcode_tok = ass.currentToken();
    if (maybe_lhs_result != null) {
        try ass.expectToken(.opcode);
    } else if (!ass.eatToken(.opcode)) {
        return ass.fail(opcode_tok.start, "expected start of instruction, found {s}", .{opcode_tok.tag.name()});
    }

    const opcode_text = ass.tokenText(opcode_tok);
    const index = ass.inst_map.getIndex(opcode_text) orelse {
        return ass.fail(opcode_tok.start, "invalid opcode '{s}'", .{opcode_text});
    };

    const inst = spec.InstructionSet.core.instructions()[index];
    ass.inst.opcode = @enumFromInt(inst.opcode);

    const expected_operands = inst.operands;
    // This is a loop because the result-id is not always the first operand.
    const requires_lhs_result = for (expected_operands) |op| {
        if (op.kind == .id_result) break true;
    } else false;

    if (requires_lhs_result and maybe_lhs_result == null) {
        return ass.fail(opcode_tok.start, "opcode '{s}' expects result on left-hand side", .{@tagName(ass.inst.opcode)});
    } else if (!requires_lhs_result and maybe_lhs_result != null) {
        return ass.fail(
            lhs_result_tok.start,
            "opcode '{s}' does not expect a result-id on the left-hand side",
            .{@tagName(ass.inst.opcode)},
        );
    }

    for (expected_operands) |operand| {
        if (operand.kind == .id_result) {
            try ass.inst.operands.append(gpa, .{ .result_id = maybe_lhs_result.? });
            continue;
        }

        switch (operand.quantifier) {
            .required => if (ass.isAtInstructionBoundary()) {
                return ass.fail(
                    ass.currentToken().start,
                    "missing required operand", // TODO: Operand name?
                    .{},
                );
            } else {
                try ass.parseOperand(operand.kind);
            },
            .optional => if (!ass.isAtInstructionBoundary()) {
                try ass.parseOperand(operand.kind);
            },
            .variadic => while (!ass.isAtInstructionBoundary()) {
                try ass.parseOperand(operand.kind);
            },
        }
    }
}

fn parseOperand(ass: *Assembler, kind: spec.OperandKind) Error!void {
    switch (kind.category()) {
        .bit_enum => try ass.parseBitEnum(kind),
        .value_enum => try ass.parseValueEnum(kind),
        .id => try ass.parseRefId(),
        else => switch (kind) {
            .literal_integer => try ass.parseLiteralInteger(),
            .literal_string => try ass.parseString(),
            .literal_context_dependent_number => try ass.parseContextDependentNumber(),
            .literal_ext_inst_integer => try ass.parseLiteralExtInstInteger(),
            .pair_id_ref_id_ref => try ass.parsePhiSource(),
            else => return ass.todo("parse operand of type {s}", .{@tagName(kind)}),
        },
    }
}

/// Also handles parsing any required extra operands.
fn parseBitEnum(ass: *Assembler, kind: spec.OperandKind) !void {
    const gpa = ass.cg.module.gpa;

    var tok = ass.currentToken();
    try ass.expectToken(.value);

    var text = ass.tokenText(tok);
    if (std.mem.eql(u8, text, "None")) {
        try ass.inst.operands.append(gpa, .{ .value = 0 });
        return;
    }

    const enumerants = kind.enumerants();
    var mask: u32 = 0;
    while (true) {
        const enumerant = for (enumerants) |enumerant| {
            if (std.mem.eql(u8, enumerant.name, text))
                break enumerant;
        } else {
            return ass.fail(tok.start, "'{s}' is not a valid flag for bitmask {s}", .{ text, @tagName(kind) });
        };
        mask |= enumerant.value;
        if (!ass.eatToken(.pipe))
            break;

        tok = ass.currentToken();
        try ass.expectToken(.value);
        text = ass.tokenText(tok);
    }

    try ass.inst.operands.append(gpa, .{ .value = mask });

    // Assume values are sorted.
    // TODO: ensure in generator.
    for (enumerants) |enumerant| {
        if ((mask & enumerant.value) == 0)
            continue;

        for (enumerant.parameters) |param_kind| {
            if (ass.isAtInstructionBoundary()) {
                return ass.fail(ass.currentToken().start, "missing required parameter for bit flag '{s}'", .{enumerant.name});
            }

            try ass.parseOperand(param_kind);
        }
    }
}

/// Also handles parsing any required extra operands.
fn parseValueEnum(ass: *Assembler, kind: spec.OperandKind) !void {
    const gpa = ass.cg.module.gpa;

    const tok = ass.currentToken();
    if (ass.eatToken(.placeholder)) {
        const name = ass.tokenText(tok)[1..];
        const value = ass.value_map.get(name) orelse {
            return ass.fail(tok.start, "invalid placeholder '${s}'", .{name});
        };
        switch (value) {
            .constant => |literal32| {
                try ass.inst.operands.append(gpa, .{ .value = literal32 });
            },
            .string => |str| {
                const enumerant = for (kind.enumerants()) |enumerant| {
                    if (std.mem.eql(u8, enumerant.name, str)) break enumerant;
                } else {
                    return ass.fail(tok.start, "'{s}' is not a valid value for enumeration {s}", .{ str, @tagName(kind) });
                };
                try ass.inst.operands.append(gpa, .{ .value = enumerant.value });
            },
            else => return ass.fail(tok.start, "value '{s}' cannot be used as placeholder", .{name}),
        }
        return;
    }

    try ass.expectToken(.value);

    const text = ass.tokenText(tok);
    const int_value = std.fmt.parseInt(u32, text, 0) catch null;
    const enumerant = for (kind.enumerants()) |enumerant| {
        if (int_value) |v| {
            if (v == enumerant.value) break enumerant;
        } else {
            if (std.mem.eql(u8, enumerant.name, text)) break enumerant;
        }
    } else {
        return ass.fail(tok.start, "'{s}' is not a valid value for enumeration {s}", .{ text, @tagName(kind) });
    };

    try ass.inst.operands.append(gpa, .{ .value = enumerant.value });

    for (enumerant.parameters) |param_kind| {
        if (ass.isAtInstructionBoundary()) {
            return ass.fail(ass.currentToken().start, "missing required parameter for enum variant '{s}'", .{enumerant.name});
        }

        try ass.parseOperand(param_kind);
    }
}

fn parseRefId(ass: *Assembler) !void {
    const gpa = ass.cg.module.gpa;

    const tok = ass.currentToken();
    try ass.expectToken(.result_id);

    const name = ass.tokenText(tok)[1..];
    const entry = try ass.value_map.getOrPut(gpa, name);
    if (!entry.found_existing) {
        entry.value_ptr.* = .unresolved_forward_reference;
    }

    const index: AsmValue.Ref = @intCast(entry.index);
    try ass.inst.operands.append(gpa, .{ .ref_id = index });
}

fn parseLiteralInteger(ass: *Assembler) !void {
    const gpa = ass.cg.module.gpa;

    const tok = ass.currentToken();
    if (ass.eatToken(.placeholder)) {
        const name = ass.tokenText(tok)[1..];
        const value = ass.value_map.get(name) orelse {
            return ass.fail(tok.start, "invalid placeholder '${s}'", .{name});
        };
        switch (value) {
            .constant => |literal32| {
                try ass.inst.operands.append(gpa, .{ .literal32 = literal32 });
            },
            else => {
                return ass.fail(tok.start, "value '{s}' cannot be used as placeholder", .{name});
            },
        }
        return;
    }

    try ass.expectToken(.value);
    // According to the SPIR-V machine readable grammar, a LiteralInteger
    // may consist of one or more words. From the SPIR-V docs it seems like there
    // only one instruction where multiple words are allowed, the literals that make up the
    // switch cases of OpSwitch. This case is handled separately, and so we just assume
    // everything is a 32-bit integer in this function.
    const text = ass.tokenText(tok);
    const value = std.fmt.parseInt(u32, text, 0) catch {
        return ass.fail(tok.start, "'{s}' is not a valid 32-bit integer literal", .{text});
    };
    try ass.inst.operands.append(gpa, .{ .literal32 = value });
}

fn parseLiteralExtInstInteger(ass: *Assembler) !void {
    const gpa = ass.cg.module.gpa;

    const tok = ass.currentToken();
    if (ass.eatToken(.placeholder)) {
        const name = ass.tokenText(tok)[1..];
        const value = ass.value_map.get(name) orelse {
            return ass.fail(tok.start, "invalid placeholder '${s}'", .{name});
        };
        switch (value) {
            .constant => |literal32| {
                try ass.inst.operands.append(gpa, .{ .literal32 = literal32 });
            },
            else => {
                return ass.fail(tok.start, "value '{s}' cannot be used as placeholder", .{name});
            },
        }
        return;
    }

    try ass.expectToken(.value);
    const text = ass.tokenText(tok);
    const value = std.fmt.parseInt(u32, text, 0) catch {
        return ass.fail(tok.start, "'{s}' is not a valid 32-bit integer literal", .{text});
    };
    try ass.inst.operands.append(gpa, .{ .literal32 = value });
}

fn parseString(ass: *Assembler) !void {
    const gpa = ass.cg.module.gpa;

    const tok = ass.currentToken();
    try ass.expectToken(.string);
    // Note, the string might not have a closing quote. In this case,
    // an error is already emitted but we are trying to continue processing
    // anyway, so in this function we have to deal with that situation.
    const text = ass.tokenText(tok);
    assert(text.len > 0 and text[0] == '"');
    const literal = if (text.len != 1 and text[text.len - 1] == '"')
        text[1 .. text.len - 1]
    else
        text[1..];

    const string_offset: u32 = @intCast(ass.inst.string_bytes.items.len);
    try ass.inst.string_bytes.ensureUnusedCapacity(gpa, literal.len + 1);
    ass.inst.string_bytes.appendSliceAssumeCapacity(literal);
    ass.inst.string_bytes.appendAssumeCapacity(0);

    try ass.inst.operands.append(gpa, .{ .string = string_offset });
}

fn parseContextDependentNumber(ass: *Assembler) !void {
    const module = ass.cg.module;

    // For context dependent numbers, the actual type to parse is determined by the instruction.
    // Currently, this operand appears in OpConstant and OpSpecConstant, where the too-be-parsed type
    // is determined by the result type. That means that in this instructions we have to resolve the
    // operand type early and look at the result to see how we need to proceed.
    assert(ass.inst.opcode == .OpConstant or ass.inst.opcode == .OpSpecConstant);

    const tok = ass.currentToken();
    const result = try ass.resolveRef(ass.inst.operands.items[0].ref_id);
    const result_id = result.resultId();
    // We are going to cheat a little bit: The types we are interested in, int and float,
    // are added to the module and cached via module.intType and module.floatType. Therefore,
    // we can determine the width of these types by directly checking the cache.
    // This only works if the Assembler and codegen both use spv.intType and spv.floatType though.
    // We don't expect there to be many of these types, so just look it up every time.
    // TODO: Count be improved to be a little bit more efficent.

    {
        var it = module.cache.int_types.iterator();
        while (it.next()) |entry| {
            const id = entry.value_ptr.*;
            if (id != result_id) continue;
            const info = entry.key_ptr.*;
            return try ass.parseContextDependentInt(info.signedness, info.bits);
        }
    }

    {
        var it = module.cache.float_types.iterator();
        while (it.next()) |entry| {
            const id = entry.value_ptr.*;
            if (id != result_id) continue;
            const info = entry.key_ptr.*;
            switch (info.bits) {
                16 => try ass.parseContextDependentFloat(16),
                32 => try ass.parseContextDependentFloat(32),
                64 => try ass.parseContextDependentFloat(64),
                else => return ass.fail(tok.start, "cannot parse {}-bit info literal", .{info.bits}),
            }
        }
    }

    return ass.fail(tok.start, "cannot parse literal constant", .{});
}

fn parseContextDependentInt(ass: *Assembler, signedness: std.builtin.Signedness, width: u32) !void {
    const gpa = ass.cg.module.gpa;

    const tok = ass.currentToken();
    if (ass.eatToken(.placeholder)) {
        const name = ass.tokenText(tok)[1..];
        const value = ass.value_map.get(name) orelse {
            return ass.fail(tok.start, "invalid placeholder '${s}'", .{name});
        };
        switch (value) {
            .constant => |literal32| {
                try ass.inst.operands.append(gpa, .{ .literal32 = literal32 });
            },
            else => {
                return ass.fail(tok.start, "value '{s}' cannot be used as placeholder", .{name});
            },
        }
        return;
    }

    try ass.expectToken(.value);

    if (width == 0 or width > 2 * @bitSizeOf(spec.Word)) {
        return ass.fail(tok.start, "cannot parse {}-bit integer literal", .{width});
    }

    const text = ass.tokenText(tok);
    invalid: {
        // Just parse the integer as the next larger integer type, and check if it overflows afterwards.
        const int = std.fmt.parseInt(i128, text, 0) catch break :invalid;
        const min = switch (signedness) {
            .unsigned => 0,
            .signed => -(@as(i128, 1) << (@as(u7, @intCast(width)) - 1)),
        };
        const max = (@as(i128, 1) << (@as(u7, @intCast(width)) - @intFromBool(signedness == .signed))) - 1;
        if (int < min or int > max) {
            break :invalid;
        }

        // Note, we store the sign-extended version here.
        if (width <= @bitSizeOf(spec.Word)) {
            try ass.inst.operands.append(gpa, .{ .literal32 = @truncate(@as(u128, @bitCast(int))) });
        } else {
            try ass.inst.operands.append(gpa, .{ .literal64 = @truncate(@as(u128, @bitCast(int))) });
        }
        return;
    }

    return ass.fail(tok.start, "'{s}' is not a valid {s} {}-bit int literal", .{ text, @tagName(signedness), width });
}

fn parseContextDependentFloat(ass: *Assembler, comptime width: u16) !void {
    const gpa = ass.cg.module.gpa;

    const Float = std.meta.Float(width);
    const Int = std.meta.Int(.unsigned, width);

    const tok = ass.currentToken();
    try ass.expectToken(.value);

    const text = ass.tokenText(tok);

    const value = std.fmt.parseFloat(Float, text) catch {
        return ass.fail(tok.start, "'{s}' is not a valid {}-bit float literal", .{ text, width });
    };

    const float_bits: Int = @bitCast(value);
    if (width <= @bitSizeOf(spec.Word)) {
        try ass.inst.operands.append(gpa, .{ .literal32 = float_bits });
    } else {
        assert(width <= 2 * @bitSizeOf(spec.Word));
        try ass.inst.operands.append(gpa, .{ .literal64 = float_bits });
    }
}

fn parsePhiSource(ass: *Assembler) !void {
    try ass.parseRefId();
    if (ass.isAtInstructionBoundary()) {
        return ass.fail(ass.currentToken().start, "missing phi block parent", .{});
    }
    try ass.parseRefId();
}

/// Returns whether the `current_token` cursor
/// is currently pointing at the start of a new instruction.
fn isAtInstructionBoundary(ass: Assembler) bool {
    return switch (ass.currentToken().tag) {
        .opcode, .result_id_assign, .eof => true,
        else => false,
    };
}

fn expectToken(ass: *Assembler, tag: Token.Tag) !void {
    if (ass.eatToken(tag))
        return;

    return ass.fail(ass.currentToken().start, "unexpected {s}, expected {s}", .{
        ass.currentToken().tag.name(),
        tag.name(),
    });
}

fn eatToken(ass: *Assembler, tag: Token.Tag) bool {
    if (ass.testToken(tag)) {
        ass.current_token += 1;
        return true;
    }
    return false;
}

fn testToken(ass: Assembler, tag: Token.Tag) bool {
    return ass.currentToken().tag == tag;
}

fn currentToken(ass: Assembler) Token {
    return ass.tokens.items[ass.current_token];
}

fn tokenText(ass: Assembler, tok: Token) []const u8 {
    return ass.src[tok.start..tok.end];
}

/// Tokenize `ass.src` and put the tokens in `ass.tokens`.
/// Any errors encountered are appended to `ass.errors`.
fn tokenize(ass: *Assembler) !void {
    const gpa = ass.cg.module.gpa;

    ass.tokens.clearRetainingCapacity();

    var offset: u32 = 0;
    while (true) {
        const tok = try ass.nextToken(offset);
        // Resolve result-id assignment now.
        // NOTE: If the previous token wasn't a result-id, just ignore it,
        // we will catch it while parsing.
        if (tok.tag == .equals and ass.tokens.items[ass.tokens.items.len - 1].tag == .result_id) {
            ass.tokens.items[ass.tokens.items.len - 1].tag = .result_id_assign;
        }
        try ass.tokens.append(gpa, tok);
        if (tok.tag == .eof)
            break;
        offset = tok.end;
    }
}

const Token = struct {
    tag: Tag,
    start: u32,
    end: u32,

    const Tag = enum {
        /// Returned when there was no more input to match.
        eof,
        /// %identifier
        result_id,
        /// %identifier when appearing on the LHS of an equals sign.
        /// While not technically a token, its relatively easy to resolve
        /// this during lexical analysis and relieves a bunch of headaches
        /// during parsing.
        result_id_assign,
        /// Mask, int, or float. These are grouped together as some
        /// SPIR-V enumerants look a bit like integers as well (for example
        /// "3D"), and so it is easier to just interpret them as the expected
        /// type when resolving an instruction's operands.
        value,
        /// An enumerant that looks like an opcode, that is, OpXxxx.
        /// Not necessarily a *valid* opcode.
        opcode,
        /// String literals.
        /// Note, this token is also returned for unterminated
        /// strings. In this case the closing " is not present.
        string,
        /// |.
        pipe,
        /// =.
        equals,
        /// $identifier. This is used (for now) for constant values, like integers.
        /// These can be used in place of a normal `value`.
        placeholder,

        fn name(tag: Tag) []const u8 {
            return switch (tag) {
                .eof => "<end of input>",
                .result_id => "<result-id>",
                .result_id_assign => "<assigned result-id>",
                .value => "<value>",
                .opcode => "<opcode>",
                .string => "<string literal>",
                .pipe => "'|'",
                .equals => "'='",
                .placeholder => "<placeholder>",
            };
        }
    };
};

/// Retrieve the next token from the input. This function will assert
/// that the token is surrounded by whitespace if required, but will not
/// interpret the token yet.
/// NOTE: This function doesn't handle .result_id_assign - this is handled in tokenize().
fn nextToken(ass: *Assembler, start_offset: u32) !Token {
    // We generally separate the input into the following types:
    // - Whitespace. Generally ignored, but also used as delimiter for some
    //   tokens.
    // - Values. This entails integers, floats, enums - anything that
    //   consists of alphanumeric characters, delimited by whitespace.
    // - Result-IDs. This entails anything that consists of alphanumeric characters and _, and
    //   starts with a %. In contrast to values, this entity can be checked for complete correctness
    //   relatively easily here.
    // - Strings. This entails quote-delimited text such as "abc".
    //   SPIR-V strings have only two escapes, \" and \\.
    // - Sigils, = and |. In this assembler, these are not required to have whitespace
    //   around them (they act as delimiters) as they do in SPIRV-Tools.

    var state: enum {
        start,
        value,
        result_id,
        string,
        string_end,
        escape,
        placeholder,
    } = .start;
    var token_start = start_offset;
    var offset = start_offset;
    var tag = Token.Tag.eof;
    while (offset < ass.src.len) : (offset += 1) {
        const c = ass.src[offset];
        switch (state) {
            .start => switch (c) {
                ' ', '\t', '\r', '\n' => token_start = offset + 1,
                '"' => {
                    state = .string;
                    tag = .string;
                },
                '%' => {
                    state = .result_id;
                    tag = .result_id;
                },
                '|' => {
                    tag = .pipe;
                    offset += 1;
                    break;
                },
                '=' => {
                    tag = .equals;
                    offset += 1;
                    break;
                },
                '$' => {
                    state = .placeholder;
                    tag = .placeholder;
                },
                else => {
                    state = .value;
                    tag = .value;
                },
            },
            .value => switch (c) {
                '"' => {
                    try ass.addError(offset, "unexpected string literal", .{});
                    // The user most likely just forgot a delimiter here - keep
                    // the tag as value.
                    break;
                },
                ' ', '\t', '\r', '\n', '=', '|' => break,
                else => {},
            },
            .result_id, .placeholder => switch (c) {
                '_', 'a'...'z', 'A'...'Z', '0'...'9' => {},
                ' ', '\t', '\r', '\n', '=', '|' => break,
                else => {
                    try ass.addError(offset, "illegal character in result-id or placeholder", .{});
                    // Again, probably a forgotten delimiter here.
                    break;
                },
            },
            .string => switch (c) {
                '\\' => state = .escape,
                '"' => state = .string_end,
                else => {}, // Note, strings may include newlines
            },
            .string_end => switch (c) {
                ' ', '\t', '\r', '\n', '=', '|' => break,
                else => {
                    try ass.addError(offset, "unexpected character after string literal", .{});
                    // The token is still unmistakibly a string.
                    break;
                },
            },
            // Escapes simply skip the next char.
            .escape => state = .string,
        }
    }

    var tok: Token = .{
        .tag = tag,
        .start = token_start,
        .end = offset,
    };

    switch (state) {
        .string, .escape => {
            try ass.addError(token_start, "unterminated string", .{});
        },
        .result_id => if (offset - token_start == 1) {
            try ass.addError(token_start, "result-id must have at least one name character", .{});
        },
        .value => {
            const text = ass.tokenText(tok);
            const prefix = "Op";
            const looks_like_opcode = text.len > prefix.len and
                std.mem.startsWith(u8, text, prefix) and
                std.ascii.isUpper(text[prefix.len]);
            if (looks_like_opcode)
                tok.tag = .opcode;
        },
        else => {},
    }

    return tok;
}
