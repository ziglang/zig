pub const Instruction = struct {
    encoding: Encoding,
    ops: [5]Operand = .{.none} ** 5,

    pub const Operand = union(enum) {
        none,
        reg: Register,
        mem: Memory,
        imm: Immediate,
        barrier: Mir.Barrier,
    };

    pub fn new(mnemonic: Encoding.Mnemonic, ops: []const Operand) !Instruction {
        const encoding = (try Encoding.findByMnemonic(mnemonic, ops)) orelse {
            std.log.err("no encoding found for:  {s} [{s} {s} {s} {s} {s}]", .{
                @tagName(mnemonic),
                @tagName(if (ops.len > 0) ops[0] else .none),
                @tagName(if (ops.len > 1) ops[1] else .none),
                @tagName(if (ops.len > 2) ops[2] else .none),
                @tagName(if (ops.len > 3) ops[3] else .none),
                @tagName(if (ops.len > 4) ops[4] else .none),
            });
            return error.InvalidInstruction;
        };

        var result_ops: [5]Operand = .{.none} ** 5;
        @memcpy(result_ops[0..ops.len], ops);

        return .{
            .encoding = encoding,
            .ops = result_ops,
        };
    }

    pub fn encode(inst: Instruction, writer: anytype) !void {
        try writer.writeInt(u32, inst.encoding.data.toU32(), .little);
    }

    pub fn format(
        inst: Instruction,
        comptime fmt: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        std.debug.assert(fmt.len == 0);

        const encoding = inst.encoding;

        try writer.print("{s} ", .{@tagName(encoding.mnemonic)});

        var i: u32 = 0;
        while (i < inst.ops.len and inst.ops[i] != .none) : (i += 1) {
            if (i != inst.ops.len and i != 0) try writer.writeAll(", ");

            switch (@as(Instruction.Operand, inst.ops[i])) {
                .none => unreachable, // it's sliced out above
                .reg => |reg| try writer.writeAll(@tagName(reg)),
                .imm => |imm| try writer.print("{d}", .{imm.asSigned(64)}),
                .mem => try writer.writeAll("mem"),
                .barrier => |barrier| try writer.writeAll(@tagName(barrier)),
            }
        }
    }
};

const std = @import("std");

const Lower = @import("Lower.zig");
const Mir = @import("Mir.zig");
const bits = @import("bits.zig");
const Encoding = @import("Encoding.zig");

const Register = bits.Register;
const Memory = bits.Memory;
const Immediate = bits.Immediate;

const log = std.log.scoped(.encode);
