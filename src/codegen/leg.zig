const std = @import("std");
const DW = std.dwarf;
const testing = std.testing;

// zig fmt: off

pub const Condition = enum(u2) {
    /// Always
    al,
    /// Equal
    eq,
    /// Greater than
    gt,
    /// Greater than or equal
    gte,
};

/// Represents a general purpose register in the LEG instruction set
pub const Register = enum(u5) {
    r0, r1, r2, r3, r4, r5, r6, r7,
    r8, r9, r10, r11, r12, r13, r14, r15,
    r16, r17, r18, r19, r20, r21, r22, r23,
    r24, r25, r26, r27, r28, r29, r30, r31,

    pub fn dwarfLocOp(self: Register) u8 {
        return @as(u8, @enumToInt(self)) + DW.OP_reg0;
    }
};

// zig fmt: on

pub const callee_preserved_regs = [_]Register{
    .r9,  .r10, .r11, .r12, .r13, .r14, .r15,
    .r16, .r17, .r18, .r19, .r20, .r21, .r22,
    .r23, .r24, .r25, .r26, .r27,
};

/// Represents an instruction in the LEG instruction set
pub const Instruction = union(enum) {
    special: packed struct {
        arg: u21,
        op: u8,
        fixed: u3 = 0b000,
    },
    jump_immediate: packed struct {
        offset: u26,
        cond: u2,
        fixed: u4 = 0b0100,
    },

    pub fn toU32(self: Instruction) u32 {
        return switch (self) {
            .special => |v| @bitCast(u32, v),
            .jump_immediate => |v| @bitCast(u32, v),
        };
    }

    // Helper functions

    fn special(arg: u21, op: u8) Instruction {
        return Instruction{
            .special = .{
                .arg = arg,
                .op = op,
            },
        };
    }

    fn jumpImmediate(offset: i26, cond: Condition) Instruction {
        return Instruction{
            .jump_immediate = .{
                .offset = @bitCast(u26, offset),
                .cond = @enumToInt(cond),
            },
        };
    }

    pub fn syscall(arg: u21) Instruction {
        return special(arg, 0x10);
    }

    pub fn jump(offset: i26, cond: Condition) Instruction {
        return jumpImmediate(offset, cond);
    }
};

test "serialize instructions" {
    const Testcase = struct {
        inst: Instruction,
        expected: u32,
    };

    const testcases = [_]Testcase{
        .{ // syscall
            .inst = Instruction.syscall(0),
            .expected = 0b000_00010000_000000000000000000000,
        },
        .{ // jmp label
            .inst = Instruction.jump(4, .al),
            .expected = 0b010_0_00_00000000000000000000000100,
        },
    };

    for (testcases) |case| {
        const actual = case.inst.toU32();
        testing.expectEqual(case.expected, actual);
    }
}
