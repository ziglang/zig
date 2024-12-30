const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.spirv_parse);

const spec = @import("../../codegen/spirv/spec.zig");
const Opcode = spec.Opcode;
const Word = spec.Word;
const InstructionSet = spec.InstructionSet;
const ResultId = spec.IdResult;

const BinaryModule = @This();

pub const header_words = 5;

/// The module SPIR-V version.
version: spec.Version,

/// The generator magic number.
generator_magic: u32,

/// The result-id bound of this SPIR-V module.
id_bound: u32,

/// The instructions of this module. This does not contain the header.
instructions: []const Word,

/// Maps OpExtInstImport result-ids to their InstructionSet.
ext_inst_map: std.AutoHashMapUnmanaged(ResultId, InstructionSet),

/// This map contains the width of arithmetic types (OpTypeInt and
/// OpTypeFloat). We need this information to correctly parse the operands
/// of Op(Spec)Constant and OpSwitch.
arith_type_width: std.AutoHashMapUnmanaged(ResultId, u16),

/// The starting offsets of some sections
sections: struct {
    functions: usize,
},

pub fn deinit(self: *BinaryModule, a: Allocator) void {
    self.ext_inst_map.deinit(a);
    self.arith_type_width.deinit(a);
    self.* = undefined;
}

pub fn iterateInstructions(self: BinaryModule) Instruction.Iterator {
    return Instruction.Iterator.init(self.instructions, 0);
}

pub fn iterateInstructionsFrom(self: BinaryModule, offset: usize) Instruction.Iterator {
    return Instruction.Iterator.init(self.instructions, offset);
}

pub fn instructionAt(self: BinaryModule, offset: usize) Instruction {
    var it = self.iterateInstructionsFrom(offset);
    return it.next().?;
}

pub fn finalize(self: BinaryModule, a: Allocator) ![]Word {
    const result = try a.alloc(Word, 5 + self.instructions.len);
    errdefer a.free(result);

    result[0] = spec.magic_number;
    result[1] = @bitCast(self.version);
    result[2] = spec.zig_generator_id;
    result[3] = self.id_bound;
    result[4] = 0; // Schema

    @memcpy(result[5..], self.instructions);
    return result;
}

/// Errors that can be raised when the module is not correct.
/// Note that the parser doesn't validate SPIR-V modules by a
/// long shot. It only yields errors that critically prevent
/// further analysis of the module.
pub const ParseError = error{
    /// Raised when the module doesn't start with the SPIR-V magic.
    /// This usually means that the module isn't actually SPIR-V.
    InvalidMagic,
    /// Raised when the module has an invalid "physical" format:
    /// For example when the header is incomplete, or an instruction
    /// has an illegal format.
    InvalidPhysicalFormat,
    /// OpExtInstImport was used with an unknown extension string.
    InvalidExtInstImport,
    /// The module had an instruction with an invalid (unknown) opcode.
    InvalidOpcode,
    /// An instruction's operands did not conform to the SPIR-V specification
    /// for that instruction.
    InvalidOperands,
    /// A result-id was declared more than once.
    DuplicateId,
    /// Some ID did not resolve.
    InvalidId,
    /// This opcode or instruction is not supported yet.
    UnsupportedOperation,
    /// Parser ran out of memory.
    OutOfMemory,
};

pub const Instruction = struct {
    pub const Iterator = struct {
        words: []const Word,
        index: usize = 0,
        offset: usize = 0,

        pub fn init(words: []const Word, start_offset: usize) Iterator {
            return .{ .words = words, .offset = start_offset };
        }

        pub fn next(self: *Iterator) ?Instruction {
            if (self.offset >= self.words.len) return null;

            const instruction_len = self.words[self.offset] >> 16;
            defer self.offset += instruction_len;
            defer self.index += 1;
            assert(instruction_len != 0);
            assert(self.offset < self.words.len);

            return Instruction{
                .opcode = @enumFromInt(self.words[self.offset] & 0xFFFF),
                .index = self.index,
                .offset = self.offset,
                .operands = self.words[self.offset..][1..instruction_len],
            };
        }
    };

    /// The opcode for this instruction.
    opcode: Opcode,
    /// The instruction's index.
    index: usize,
    /// The instruction's word offset in the module.
    offset: usize,
    /// The raw (unparsed) operands for this instruction.
    operands: []const Word,
};

/// This parser contains information (acceleration tables)
/// that can be persisted across different modules. This is
/// used to initialize the module, and is also used when
/// further analyzing it.
pub const Parser = struct {
    /// The allocator used to allocate this parser's structures,
    /// and also the structures of any parsed module.
    a: Allocator,

    /// Maps (instruction set, opcode) => instruction index (for instruction set)
    opcode_table: std.AutoHashMapUnmanaged(u32, u16) = .empty,

    pub fn init(a: Allocator) !Parser {
        var self = Parser{
            .a = a,
        };
        errdefer self.deinit();

        inline for (std.meta.tags(InstructionSet)) |set| {
            const instructions = set.instructions();
            try self.opcode_table.ensureUnusedCapacity(a, @intCast(instructions.len));
            for (instructions, 0..) |inst, i| {
                // Note: Some instructions may alias another. In this case we don't really care
                // which one is first: they all (should) have the same operands anyway. Just pick
                // the first, which is usually the core, KHR or EXT variant.
                const entry = self.opcode_table.getOrPutAssumeCapacity(mapSetAndOpcode(set, @intCast(inst.opcode)));
                if (!entry.found_existing) {
                    entry.value_ptr.* = @intCast(i);
                }
            }
        }

        return self;
    }

    pub fn deinit(self: *Parser) void {
        self.opcode_table.deinit(self.a);
    }

    fn mapSetAndOpcode(set: InstructionSet, opcode: u16) u32 {
        return (@as(u32, @intFromEnum(set)) << 16) | opcode;
    }

    pub fn getInstSpec(self: Parser, opcode: Opcode) ?spec.Instruction {
        const index = self.opcode_table.get(mapSetAndOpcode(.core, @intFromEnum(opcode))) orelse return null;
        return InstructionSet.core.instructions()[index];
    }

    pub fn parse(self: *Parser, module: []const u32) ParseError!BinaryModule {
        if (module[0] != spec.magic_number) {
            return error.InvalidMagic;
        } else if (module.len < header_words) {
            log.err("module only has {}/{} header words", .{ module.len, header_words });
            return error.InvalidPhysicalFormat;
        }

        var binary = BinaryModule{
            .version = @bitCast(module[1]),
            .generator_magic = module[2],
            .id_bound = module[3],
            .instructions = module[header_words..],
            .ext_inst_map = .{},
            .arith_type_width = .{},
            .sections = undefined,
        };

        var maybe_function_section: ?usize = null;

        // First pass through the module to verify basic structure and
        // to gather some initial stuff for more detailed analysis.
        // We want to check some stuff that Instruction.Iterator is no good for,
        // so just iterate manually.
        var offset: usize = 0;
        while (offset < binary.instructions.len) {
            const len = binary.instructions[offset] >> 16;
            if (len == 0 or len + offset > binary.instructions.len) {
                log.err("invalid instruction format: len={}, end={}, module len={}", .{ len, len + offset, binary.instructions.len });
                return error.InvalidPhysicalFormat;
            }
            defer offset += len;

            // We can't really efficiently use non-exhaustive enums here, because we would
            // need to manually write out all valid cases. Since we have this map anyway, just
            // use that.
            const opcode: Opcode = @enumFromInt(@as(u16, @truncate(binary.instructions[offset])));
            const inst_spec = self.getInstSpec(opcode) orelse {
                log.err("invalid opcode for core set: {}", .{@intFromEnum(opcode)});
                return error.InvalidOpcode;
            };

            const operands = binary.instructions[offset..][1..len];
            switch (opcode) {
                .OpExtInstImport => {
                    const set_name = std.mem.sliceTo(std.mem.sliceAsBytes(operands[1..]), 0);
                    const set = std.meta.stringToEnum(InstructionSet, set_name) orelse {
                        log.err("invalid instruction set '{s}'", .{set_name});
                        return error.InvalidExtInstImport;
                    };
                    if (set == .core) return error.InvalidExtInstImport;
                    try binary.ext_inst_map.put(self.a, @enumFromInt(operands[0]), set);
                },
                .OpTypeInt, .OpTypeFloat => {
                    const entry = try binary.arith_type_width.getOrPut(self.a, @enumFromInt(operands[0]));
                    if (entry.found_existing) return error.DuplicateId;
                    entry.value_ptr.* = std.math.cast(u16, operands[1]) orelse return error.InvalidOperands;
                },
                .OpFunction => if (maybe_function_section == null) {
                    maybe_function_section = offset;
                },
                else => {},
            }

            // OpSwitch takes a value as argument, not an OpType... hence we need to populate arith_type_width
            // with ALL operations that return an int or float.
            const spec_operands = inst_spec.operands;
            if (spec_operands.len >= 2 and
                spec_operands[0].kind == .IdResultType and
                spec_operands[1].kind == .IdResult)
            {
                if (operands.len < 2) return error.InvalidOperands;
                if (binary.arith_type_width.get(@enumFromInt(operands[0]))) |width| {
                    const entry = try binary.arith_type_width.getOrPut(self.a, @enumFromInt(operands[1]));
                    if (entry.found_existing) return error.DuplicateId;
                    entry.value_ptr.* = width;
                }
            }
        }

        binary.sections = .{
            .functions = maybe_function_section orelse binary.instructions.len,
        };

        return binary;
    }

    /// Parse offsets in the instruction that contain result-ids.
    /// Returned offsets are relative to inst.operands.
    /// Returns in an arraylist to armortize allocations.
    pub fn parseInstructionResultIds(
        self: *Parser,
        binary: BinaryModule,
        inst: Instruction,
        offsets: *std.ArrayList(u16),
    ) !void {
        const index = self.opcode_table.get(mapSetAndOpcode(.core, @intFromEnum(inst.opcode))).?;
        const operands = InstructionSet.core.instructions()[index].operands;

        var offset: usize = 0;
        switch (inst.opcode) {
            .OpSpecConstantOp => {
                assert(operands[0].kind == .IdResultType);
                assert(operands[1].kind == .IdResult);
                offset = try self.parseOperandsResultIds(binary, inst, operands[0..2], offset, offsets);

                if (offset >= inst.operands.len) return error.InvalidPhysicalFormat;
                const spec_opcode = std.math.cast(u16, inst.operands[offset]) orelse return error.InvalidPhysicalFormat;
                const spec_index = self.opcode_table.get(mapSetAndOpcode(.core, spec_opcode)) orelse
                    return error.InvalidPhysicalFormat;
                const spec_operands = InstructionSet.core.instructions()[spec_index].operands;
                assert(spec_operands[0].kind == .IdResultType);
                assert(spec_operands[1].kind == .IdResult);
                offset = try self.parseOperandsResultIds(binary, inst, spec_operands[2..], offset + 1, offsets);
            },
            .OpExtInst => {
                assert(operands[0].kind == .IdResultType);
                assert(operands[1].kind == .IdResult);
                offset = try self.parseOperandsResultIds(binary, inst, operands[0..2], offset, offsets);

                if (offset + 1 >= inst.operands.len) return error.InvalidPhysicalFormat;
                const set_id: ResultId = @enumFromInt(inst.operands[offset]);
                try offsets.append(@intCast(offset));
                const set = binary.ext_inst_map.get(set_id) orelse {
                    log.err("invalid instruction set {}", .{@intFromEnum(set_id)});
                    return error.InvalidId;
                };
                const ext_opcode = std.math.cast(u16, inst.operands[offset + 1]) orelse return error.InvalidPhysicalFormat;
                const ext_index = self.opcode_table.get(mapSetAndOpcode(set, ext_opcode)) orelse
                    return error.InvalidPhysicalFormat;
                const ext_operands = set.instructions()[ext_index].operands;
                offset = try self.parseOperandsResultIds(binary, inst, ext_operands, offset + 2, offsets);
            },
            else => {
                offset = try self.parseOperandsResultIds(binary, inst, operands, offset, offsets);
            },
        }

        if (offset != inst.operands.len) return error.InvalidPhysicalFormat;
    }

    fn parseOperandsResultIds(
        self: *Parser,
        binary: BinaryModule,
        inst: Instruction,
        operands: []const spec.Operand,
        start_offset: usize,
        offsets: *std.ArrayList(u16),
    ) !usize {
        var offset = start_offset;
        for (operands) |operand| {
            offset = try self.parseOperandResultIds(binary, inst, operand, offset, offsets);
        }
        return offset;
    }

    fn parseOperandResultIds(
        self: *Parser,
        binary: BinaryModule,
        inst: Instruction,
        operand: spec.Operand,
        start_offset: usize,
        offsets: *std.ArrayList(u16),
    ) !usize {
        var offset = start_offset;
        switch (operand.quantifier) {
            .variadic => while (offset < inst.operands.len) {
                offset = try self.parseOperandKindResultIds(binary, inst, operand.kind, offset, offsets);
            },
            .optional => if (offset < inst.operands.len) {
                offset = try self.parseOperandKindResultIds(binary, inst, operand.kind, offset, offsets);
            },
            .required => {
                offset = try self.parseOperandKindResultIds(binary, inst, operand.kind, offset, offsets);
            },
        }
        return offset;
    }

    fn parseOperandKindResultIds(
        self: *Parser,
        binary: BinaryModule,
        inst: Instruction,
        kind: spec.OperandKind,
        start_offset: usize,
        offsets: *std.ArrayList(u16),
    ) !usize {
        var offset = start_offset;
        if (offset >= inst.operands.len) return error.InvalidPhysicalFormat;

        switch (kind.category()) {
            .bit_enum => {
                const mask = inst.operands[offset];
                offset += 1;
                for (kind.enumerants()) |enumerant| {
                    if ((mask & enumerant.value) != 0) {
                        for (enumerant.parameters) |param_kind| {
                            offset = try self.parseOperandKindResultIds(binary, inst, param_kind, offset, offsets);
                        }
                    }
                }
            },
            .value_enum => {
                const value = inst.operands[offset];
                offset += 1;
                for (kind.enumerants()) |enumerant| {
                    if (value == enumerant.value) {
                        for (enumerant.parameters) |param_kind| {
                            offset = try self.parseOperandKindResultIds(binary, inst, param_kind, offset, offsets);
                        }
                        break;
                    }
                }
            },
            .id => {
                try offsets.append(@intCast(offset));
                offset += 1;
            },
            else => switch (kind) {
                .LiteralInteger, .LiteralFloat => offset += 1,
                .LiteralString => while (true) {
                    if (offset >= inst.operands.len) return error.InvalidPhysicalFormat;
                    const word = inst.operands[offset];
                    offset += 1;

                    if (word & 0xFF000000 == 0 or
                        word & 0x00FF0000 == 0 or
                        word & 0x0000FF00 == 0 or
                        word & 0x000000FF == 0)
                    {
                        break;
                    }
                },
                .LiteralContextDependentNumber => {
                    assert(inst.opcode == .OpConstant or inst.opcode == .OpSpecConstantOp);
                    const bit_width = binary.arith_type_width.get(@enumFromInt(inst.operands[0])) orelse {
                        log.err("invalid LiteralContextDependentNumber type {}", .{inst.operands[0]});
                        return error.InvalidId;
                    };
                    offset += switch (bit_width) {
                        1...32 => 1,
                        33...64 => 2,
                        else => unreachable,
                    };
                },
                .LiteralExtInstInteger => unreachable,
                .LiteralSpecConstantOpInteger => unreachable,
                .PairLiteralIntegerIdRef => { // Switch case
                    assert(inst.opcode == .OpSwitch);
                    const bit_width = binary.arith_type_width.get(@enumFromInt(inst.operands[0])) orelse {
                        log.err("invalid OpSwitch type {}", .{inst.operands[0]});
                        return error.InvalidId;
                    };
                    offset += switch (bit_width) {
                        1...32 => 1,
                        33...64 => 2,
                        else => unreachable,
                    };
                    try offsets.append(@intCast(offset));
                    offset += 1;
                },
                .PairIdRefLiteralInteger => {
                    try offsets.append(@intCast(offset));
                    offset += 2;
                },
                .PairIdRefIdRef => {
                    try offsets.append(@intCast(offset));
                    try offsets.append(@intCast(offset + 1));
                    offset += 2;
                },
                else => unreachable,
            },
        }
        return offset;
    }
};
