//! Represents a section or subsection of instructions in a SPIR-V binary. Instructions can be append
//! to separate sections, which can then later be merged into the final binary.
const Section = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

const spec = @import("spec.zig");
const Word = spec.Word;
const DoubleWord = std.meta.Int(.unsigned, @bitSizeOf(Word) * 2);
const Log2Word = std.math.Log2Int(Word);

const Opcode = spec.Opcode;

instructions: std.ArrayListUnmanaged(Word) = .empty,

pub fn deinit(section: *Section, allocator: Allocator) void {
    section.instructions.deinit(allocator);
    section.* = undefined;
}

pub fn reset(section: *Section) void {
    section.instructions.clearRetainingCapacity();
}

pub fn toWords(section: Section) []Word {
    return section.instructions.items;
}

/// Append the instructions from another section into this section.
pub fn append(section: *Section, allocator: Allocator, other_section: Section) !void {
    try section.instructions.appendSlice(allocator, other_section.instructions.items);
}

pub fn ensureUnusedCapacity(
    section: *Section,
    allocator: Allocator,
    words: usize,
) !void {
    try section.instructions.ensureUnusedCapacity(allocator, words);
}

/// Write an instruction and size, operands are to be inserted manually.
pub fn emitRaw(
    section: *Section,
    allocator: Allocator,
    opcode: Opcode,
    operand_words: usize,
) !void {
    const word_count = 1 + operand_words;
    try section.instructions.ensureUnusedCapacity(allocator, word_count);
    section.writeWord((@as(Word, @intCast(word_count << 16))) | @intFromEnum(opcode));
}

/// Write an entire instruction, including all operands
pub fn emitRawInstruction(
    section: *Section,
    allocator: Allocator,
    opcode: Opcode,
    operands: []const Word,
) !void {
    try section.emitRaw(allocator, opcode, operands.len);
    section.writeWords(operands);
}

pub fn emitAssumeCapacity(
    section: *Section,
    comptime opcode: spec.Opcode,
    operands: opcode.Operands(),
) !void {
    const word_count = instructionSize(opcode, operands);
    section.writeWord(@as(Word, @intCast(word_count << 16)) | @intFromEnum(opcode));
    section.writeOperands(opcode.Operands(), operands);
}

pub fn emit(
    section: *Section,
    allocator: Allocator,
    comptime opcode: spec.Opcode,
    operands: opcode.Operands(),
) !void {
    const word_count = instructionSize(opcode, operands);
    try section.instructions.ensureUnusedCapacity(allocator, word_count);
    section.writeWord(@as(Word, @intCast(word_count << 16)) | @intFromEnum(opcode));
    section.writeOperands(opcode.Operands(), operands);
}

pub fn writeWord(section: *Section, word: Word) void {
    section.instructions.appendAssumeCapacity(word);
}

pub fn writeWords(section: *Section, words: []const Word) void {
    section.instructions.appendSliceAssumeCapacity(words);
}

pub fn writeDoubleWord(section: *Section, dword: DoubleWord) void {
    section.writeWords(&.{
        @truncate(dword),
        @truncate(dword >> @bitSizeOf(Word)),
    });
}

fn writeOperands(section: *Section, comptime Operands: type, operands: Operands) void {
    const fields = switch (@typeInfo(Operands)) {
        .@"struct" => |info| info.fields,
        .void => return,
        else => unreachable,
    };
    inline for (fields) |field| {
        section.writeOperand(field.type, @field(operands, field.name));
    }
}

pub fn writeOperand(section: *Section, comptime Operand: type, operand: Operand) void {
    switch (Operand) {
        spec.LiteralSpecConstantOpInteger => unreachable,
        spec.Id => section.writeWord(@intFromEnum(operand)),
        spec.LiteralInteger => section.writeWord(operand),
        spec.LiteralString => section.writeString(operand),
        spec.LiteralContextDependentNumber => section.writeContextDependentNumber(operand),
        spec.LiteralExtInstInteger => section.writeWord(operand.inst),
        spec.PairLiteralIntegerIdRef => section.writeWords(&.{ operand.value, @enumFromInt(operand.label) }),
        spec.PairIdRefLiteralInteger => section.writeWords(&.{ @intFromEnum(operand.target), operand.member }),
        spec.PairIdRefIdRef => section.writeWords(&.{ @intFromEnum(operand[0]), @intFromEnum(operand[1]) }),
        else => switch (@typeInfo(Operand)) {
            .@"enum" => section.writeWord(@intFromEnum(operand)),
            .optional => |info| if (operand) |child| section.writeOperand(info.child, child),
            .pointer => |info| {
                std.debug.assert(info.size == .slice); // Should be no other pointer types in the spec.
                for (operand) |item| {
                    section.writeOperand(info.child, item);
                }
            },
            .@"struct" => |info| {
                if (info.layout == .@"packed") {
                    section.writeWord(@as(Word, @bitCast(operand)));
                } else {
                    section.writeExtendedMask(Operand, operand);
                }
            },
            .@"union" => section.writeExtendedUnion(Operand, operand),
            else => unreachable,
        },
    }
}

fn writeString(section: *Section, str: []const u8) void {
    const zero_terminated_len = str.len + 1;
    var i: usize = 0;
    while (i < zero_terminated_len) : (i += @sizeOf(Word)) {
        var word: Word = 0;
        var j: usize = 0;
        while (j < @sizeOf(Word) and i + j < str.len) : (j += 1) {
            word |= @as(Word, str[i + j]) << @as(Log2Word, @intCast(j * @bitSizeOf(u8)));
        }
        section.instructions.appendAssumeCapacity(word);
    }
}

fn writeContextDependentNumber(section: *Section, operand: spec.LiteralContextDependentNumber) void {
    switch (operand) {
        .int32 => |int| section.writeWord(@bitCast(int)),
        .uint32 => |int| section.writeWord(@bitCast(int)),
        .int64 => |int| section.writeDoubleWord(@bitCast(int)),
        .uint64 => |int| section.writeDoubleWord(@bitCast(int)),
        .float32 => |float| section.writeWord(@bitCast(float)),
        .float64 => |float| section.writeDoubleWord(@bitCast(float)),
    }
}

fn writeExtendedMask(section: *Section, comptime Operand: type, operand: Operand) void {
    var mask: Word = 0;
    inline for (@typeInfo(Operand).@"struct".fields, 0..) |field, bit| {
        switch (@typeInfo(field.type)) {
            .optional => if (@field(operand, field.name) != null) {
                mask |= 1 << @as(u5, @intCast(bit));
            },
            .bool => if (@field(operand, field.name)) {
                mask |= 1 << @as(u5, @intCast(bit));
            },
            else => unreachable,
        }
    }

    section.writeWord(mask);

    inline for (@typeInfo(Operand).@"struct".fields) |field| {
        switch (@typeInfo(field.type)) {
            .optional => |info| if (@field(operand, field.name)) |child| {
                section.writeOperands(info.child, child);
            },
            .bool => {},
            else => unreachable,
        }
    }
}

fn writeExtendedUnion(section: *Section, comptime Operand: type, operand: Operand) void {
    return switch (operand) {
        inline else => |op, tag| {
            section.writeWord(@intFromEnum(tag));
            section.writeOperands(
                @FieldType(Operand, @tagName(tag)),
                op,
            );
        },
    };
}

fn instructionSize(comptime opcode: spec.Opcode, operands: opcode.Operands()) usize {
    return operandsSize(opcode.Operands(), operands) + 1;
}

fn operandsSize(comptime Operands: type, operands: Operands) usize {
    const fields = switch (@typeInfo(Operands)) {
        .@"struct" => |info| info.fields,
        .void => return 0,
        else => unreachable,
    };

    var total: usize = 0;
    inline for (fields) |field| {
        total += operandSize(field.type, @field(operands, field.name));
    }

    return total;
}

fn operandSize(comptime Operand: type, operand: Operand) usize {
    return switch (Operand) {
        spec.LiteralSpecConstantOpInteger => unreachable,
        spec.Id, spec.LiteralInteger, spec.LiteralExtInstInteger => 1,
        spec.LiteralString => std.math.divCeil(usize, operand.len + 1, @sizeOf(Word)) catch unreachable,
        spec.LiteralContextDependentNumber => switch (operand) {
            .int32, .uint32, .float32 => 1,
            .int64, .uint64, .float64 => 2,
        },
        spec.PairLiteralIntegerIdRef, spec.PairIdRefLiteralInteger, spec.PairIdRefIdRef => 2,
        else => switch (@typeInfo(Operand)) {
            .@"enum" => 1,
            .optional => |info| if (operand) |child| operandSize(info.child, child) else 0,
            .pointer => |info| blk: {
                std.debug.assert(info.size == .slice); // Should be no other pointer types in the spec.
                var total: usize = 0;
                for (operand) |item| {
                    total += operandSize(info.child, item);
                }
                break :blk total;
            },
            .@"struct" => |struct_info| {
                if (struct_info.layout == .@"packed") return 1;

                var total: usize = 0;
                inline for (@typeInfo(Operand).@"struct".fields) |field| {
                    switch (@typeInfo(field.type)) {
                        .optional => |info| if (@field(operand, field.name)) |child| {
                            total += operandsSize(info.child, child);
                        },
                        .bool => {},
                        else => unreachable,
                    }
                }
                return total + 1; // Add one for the mask itself.
            },
            .@"union" => switch (operand) {
                inline else => |op, tag| operandsSize(@FieldType(Operand, @tagName(tag)), op) + 1,
            },
            else => unreachable,
        },
    };
}
