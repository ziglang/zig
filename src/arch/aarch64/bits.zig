const std = @import("std");
const builtin = @import("builtin");
const DW = std.dwarf;
const assert = std.debug.assert;
const testing = std.testing;

// zig fmt: off

/// General purpose registers in the AArch64 instruction set
pub const Register = enum(u6) {
    // 64-bit registers
    x0, x1, x2, x3, x4, x5, x6, x7,
    x8, x9, x10, x11, x12, x13, x14, x15,
    x16, x17, x18, x19, x20, x21, x22, x23,
    x24, x25, x26, x27, x28, x29, x30, xzr,

    // 32-bit registers
    w0, w1, w2, w3, w4, w5, w6, w7,
    w8, w9, w10, w11, w12, w13, w14, w15,
    w16, w17, w18, w19, w20, w21, w22, w23,
    w24, w25, w26, w27, w28, w29, w30, wzr,

    pub const sp = Register.xzr;

    pub fn id(self: Register) u5 {
        return @truncate(u5, @enumToInt(self));
    }

    /// Returns the bit-width of the register.
    pub fn size(self: Register) u7 {
        return switch (@enumToInt(self)) {
            0...31 => 64,
            32...63 => 32,
        };
    }

    /// Convert from any register to its 64 bit alias.
    pub fn to64(self: Register) Register {
        return @intToEnum(Register, self.id());
    }

    /// Convert from any register to its 32 bit alias.
    pub fn to32(self: Register) Register {
        return @intToEnum(Register, @as(u6, self.id()) + 32);
    }

    /// Returns the index into `callee_preserved_regs`.
    pub fn allocIndex(self: Register) ?u4 {
        inline for (callee_preserved_regs) |cpreg, i| {
            if (self.id() == cpreg.id()) return i;
        }
        return null;
    }

    pub fn dwarfLocOp(self: Register) u8 {
        return @as(u8, self.id()) + DW.OP.reg0;
    }
};

// zig fmt: on

const callee_preserved_regs_impl = if (builtin.os.tag.isDarwin()) struct {
    pub const callee_preserved_regs = [_]Register{
        .x20, .x21, .x22, .x23,
        .x24, .x25, .x26, .x27,
        .x28,
    };
} else struct {
    pub const callee_preserved_regs = [_]Register{
        .x19, .x20, .x21, .x22, .x23,
        .x24, .x25, .x26, .x27, .x28,
    };
};
pub const callee_preserved_regs = callee_preserved_regs_impl.callee_preserved_regs;

pub const c_abi_int_param_regs = [_]Register{ .x0, .x1, .x2, .x3, .x4, .x5, .x6, .x7 };
pub const c_abi_int_return_regs = [_]Register{ .x0, .x1, .x2, .x3, .x4, .x5, .x6, .x7 };

test "Register.id" {
    try testing.expectEqual(@as(u5, 0), Register.x0.id());
    try testing.expectEqual(@as(u5, 0), Register.w0.id());

    try testing.expectEqual(@as(u5, 31), Register.xzr.id());
    try testing.expectEqual(@as(u5, 31), Register.wzr.id());

    try testing.expectEqual(@as(u5, 31), Register.sp.id());
    try testing.expectEqual(@as(u5, 31), Register.sp.id());
}

test "Register.size" {
    try testing.expectEqual(@as(u7, 64), Register.x19.size());
    try testing.expectEqual(@as(u7, 32), Register.w3.size());
}

test "Register.to64/to32" {
    try testing.expectEqual(Register.x0, Register.w0.to64());
    try testing.expectEqual(Register.x0, Register.x0.to64());

    try testing.expectEqual(Register.w3, Register.w3.to32());
    try testing.expectEqual(Register.w3, Register.x3.to32());
}

// zig fmt: off

/// Scalar floating point registers in the aarch64 instruction set
pub const FloatingPointRegister = enum(u8) {
    // 128-bit registers
    q0, q1, q2, q3, q4, q5, q6, q7,
    q8, q9, q10, q11, q12, q13, q14, q15,
    q16, q17, q18, q19, q20, q21, q22, q23,
    q24, q25, q26, q27, q28, q29, q30, q31,

    // 64-bit registers
    d0, d1, d2, d3, d4, d5, d6, d7,
    d8, d9, d10, d11, d12, d13, d14, d15,
    d16, d17, d18, d19, d20, d21, d22, d23,
    d24, d25, d26, d27, d28, d29, d30, d31,

    // 32-bit registers
    s0, s1, s2, s3, s4, s5, s6, s7,
    s8, s9, s10, s11, s12, s13, s14, s15,
    s16, s17, s18, s19, s20, s21, s22, s23,
    s24, s25, s26, s27, s28, s29, s30, s31,

    // 16-bit registers
    h0, h1, h2, h3, h4, h5, h6, h7,
    h8, h9, h10, h11, h12, h13, h14, h15,
    h16, h17, h18, h19, h20, h21, h22, h23,
    h24, h25, h26, h27, h28, h29, h30, h31,

    // 8-bit registers
    b0, b1, b2, b3, b4, b5, b6, b7,
    b8, b9, b10, b11, b12, b13, b14, b15,
    b16, b17, b18, b19, b20, b21, b22, b23,
    b24, b25, b26, b27, b28, b29, b30, b31,

    pub fn id(self: FloatingPointRegister) u5 {
        return @truncate(u5, @enumToInt(self));
    }

    /// Returns the bit-width of the register.
    pub fn size(self: FloatingPointRegister) u8 {
        return switch (@enumToInt(self)) {
            0...31 => 128,
            32...63 => 64,
            64...95 => 32,
            96...127 => 16,
            128...159 => 8,
            else => unreachable,
        };
    }

    /// Convert from any register to its 128 bit alias.
    pub fn to128(self: FloatingPointRegister) FloatingPointRegister {
        return @intToEnum(FloatingPointRegister, self.id());
    }

    /// Convert from any register to its 64 bit alias.
    pub fn to64(self: FloatingPointRegister) FloatingPointRegister {
        return @intToEnum(FloatingPointRegister, @as(u8, self.id()) + 32);
    }

    /// Convert from any register to its 32 bit alias.
    pub fn to32(self: FloatingPointRegister) FloatingPointRegister {
        return @intToEnum(FloatingPointRegister, @as(u8, self.id()) + 64);
    }

    /// Convert from any register to its 16 bit alias.
    pub fn to16(self: FloatingPointRegister) FloatingPointRegister {
        return @intToEnum(FloatingPointRegister, @as(u8, self.id()) + 96);
    }

    /// Convert from any register to its 8 bit alias.
    pub fn to8(self: FloatingPointRegister) FloatingPointRegister {
        return @intToEnum(FloatingPointRegister, @as(u8, self.id()) + 128);
    }
};

// zig fmt: on

test "FloatingPointRegister.id" {
    try testing.expectEqual(@as(u5, 0), FloatingPointRegister.b0.id());
    try testing.expectEqual(@as(u5, 0), FloatingPointRegister.h0.id());
    try testing.expectEqual(@as(u5, 0), FloatingPointRegister.s0.id());
    try testing.expectEqual(@as(u5, 0), FloatingPointRegister.d0.id());
    try testing.expectEqual(@as(u5, 0), FloatingPointRegister.q0.id());

    try testing.expectEqual(@as(u5, 2), FloatingPointRegister.q2.id());
    try testing.expectEqual(@as(u5, 31), FloatingPointRegister.d31.id());
}

test "FloatingPointRegister.size" {
    try testing.expectEqual(@as(u8, 128), FloatingPointRegister.q1.size());
    try testing.expectEqual(@as(u8, 64), FloatingPointRegister.d2.size());
    try testing.expectEqual(@as(u8, 32), FloatingPointRegister.s3.size());
    try testing.expectEqual(@as(u8, 16), FloatingPointRegister.h4.size());
    try testing.expectEqual(@as(u8, 8), FloatingPointRegister.b5.size());
}

test "FloatingPointRegister.toX" {
    try testing.expectEqual(FloatingPointRegister.q1, FloatingPointRegister.q1.to128());
    try testing.expectEqual(FloatingPointRegister.q2, FloatingPointRegister.b2.to128());
    try testing.expectEqual(FloatingPointRegister.q3, FloatingPointRegister.h3.to128());

    try testing.expectEqual(FloatingPointRegister.d0, FloatingPointRegister.q0.to64());
    try testing.expectEqual(FloatingPointRegister.s1, FloatingPointRegister.d1.to32());
    try testing.expectEqual(FloatingPointRegister.h2, FloatingPointRegister.s2.to16());
    try testing.expectEqual(FloatingPointRegister.b3, FloatingPointRegister.h3.to8());
}

/// Represents an instruction in the AArch64 instruction set
pub const Instruction = union(enum) {
    move_wide_immediate: packed struct {
        rd: u5,
        imm16: u16,
        hw: u2,
        fixed: u6 = 0b100101,
        opc: u2,
        sf: u1,
    },
    pc_relative_address: packed struct {
        rd: u5,
        immhi: u19,
        fixed: u5 = 0b10000,
        immlo: u2,
        op: u1,
    },
    load_store_register: packed struct {
        rt: u5,
        rn: u5,
        offset: u12,
        opc: u2,
        op1: u2,
        v: u1,
        fixed: u3 = 0b111,
        size: u2,
    },
    load_store_register_pair: packed struct {
        rt1: u5,
        rn: u5,
        rt2: u5,
        imm7: u7,
        load: u1,
        encoding: u2,
        fixed: u5 = 0b101_0_0,
        opc: u2,
    },
    load_literal: packed struct {
        rt: u5,
        imm19: u19,
        fixed: u6 = 0b011_0_00,
        opc: u2,
    },
    exception_generation: packed struct {
        ll: u2,
        op2: u3,
        imm16: u16,
        opc: u3,
        fixed: u8 = 0b1101_0100,
    },
    unconditional_branch_register: packed struct {
        op4: u5,
        rn: u5,
        op3: u6,
        op2: u5,
        opc: u4,
        fixed: u7 = 0b1101_011,
    },
    unconditional_branch_immediate: packed struct {
        imm26: u26,
        fixed: u5 = 0b00101,
        op: u1,
    },
    no_operation: packed struct {
        fixed: u32 = 0b1101010100_0_00_011_0010_0000_000_11111,
    },
    logical_shifted_register: packed struct {
        rd: u5,
        rn: u5,
        imm6: u6,
        rm: u5,
        n: u1,
        shift: u2,
        fixed: u5 = 0b01010,
        opc: u2,
        sf: u1,
    },
    add_subtract_immediate: packed struct {
        rd: u5,
        rn: u5,
        imm12: u12,
        sh: u1,
        fixed: u6 = 0b100010,
        s: u1,
        op: u1,
        sf: u1,
    },
    add_subtract_shifted_register: packed struct {
        rd: u5,
        rn: u5,
        imm6: u6,
        rm: u5,
        fixed_1: u1 = 0b0,
        shift: u2,
        fixed_2: u5 = 0b01011,
        s: u1,
        op: u1,
        sf: u1,
    },
    conditional_branch: struct {
        cond: u4,
        o0: u1,
        imm19: u19,
        o1: u1,
        fixed: u7 = 0b0101010,
    },
    compare_and_branch: struct {
        rt: u5,
        imm19: u19,
        op: u1,
        fixed: u6 = 0b011010,
        sf: u1,
    },
    conditional_select: struct {
        rd: u5,
        rn: u5,
        op2: u2,
        cond: u4,
        rm: u5,
        fixed: u8 = 0b11010100,
        s: u1,
        op: u1,
        sf: u1,
    },

    pub const Shift = struct {
        shift: Type = .lsl,
        amount: u6 = 0,

        pub const Type = enum(u2) {
            lsl,
            lsr,
            asr,
            ror,
        };

        pub const none = Shift{
            .shift = .lsl,
            .amount = 0,
        };
    };

    pub const Condition = enum(u4) {
        /// Integer: Equal
        /// Floating point: Equal
        eq,
        /// Integer: Not equal
        /// Floating point: Not equal or unordered
        ne,
        /// Integer: Carry set
        /// Floating point: Greater than, equal, or unordered
        cs,
        /// Integer: Carry clear
        /// Floating point: Less than
        cc,
        /// Integer: Minus, negative
        /// Floating point: Less than
        mi,
        /// Integer: Plus, positive or zero
        /// Floating point: Greater than, equal, or unordered
        pl,
        /// Integer: Overflow
        /// Floating point: Unordered
        vs,
        /// Integer: No overflow
        /// Floating point: Ordered
        vc,
        /// Integer: Unsigned higher
        /// Floating point: Greater than, or unordered
        hi,
        /// Integer: Unsigned lower or same
        /// Floating point: Less than or equal
        ls,
        /// Integer: Signed greater than or equal
        /// Floating point: Greater than or equal
        ge,
        /// Integer: Signed less than
        /// Floating point: Less than, or unordered
        lt,
        /// Integer: Signed greater than
        /// Floating point: Greater than
        gt,
        /// Integer: Signed less than or equal
        /// Floating point: Less than, equal, or unordered
        le,
        /// Integer: Always
        /// Floating point: Always
        al,
        /// Integer: Always
        /// Floating point: Always
        nv,

        /// Converts a std.math.CompareOperator into a condition flag,
        /// i.e. returns the condition that is true iff the result of the
        /// comparison is true. Assumes signed comparison
        pub fn fromCompareOperatorSigned(op: std.math.CompareOperator) Condition {
            return switch (op) {
                .gte => .ge,
                .gt => .gt,
                .neq => .ne,
                .lt => .lt,
                .lte => .le,
                .eq => .eq,
            };
        }

        /// Converts a std.math.CompareOperator into a condition flag,
        /// i.e. returns the condition that is true iff the result of the
        /// comparison is true. Assumes unsigned comparison
        pub fn fromCompareOperatorUnsigned(op: std.math.CompareOperator) Condition {
            return switch (op) {
                .gte => .cs,
                .gt => .hi,
                .neq => .ne,
                .lt => .cc,
                .lte => .ls,
                .eq => .eq,
            };
        }

        /// Returns the condition which is true iff the given condition is
        /// false (if such a condition exists)
        pub fn negate(cond: Condition) Condition {
            return switch (cond) {
                .eq => .ne,
                .ne => .eq,
                .cs => .cc,
                .cc => .cs,
                .mi => .pl,
                .pl => .mi,
                .vs => .vc,
                .vc => .vs,
                .hi => .ls,
                .ls => .hi,
                .ge => .lt,
                .lt => .ge,
                .gt => .le,
                .le => .gt,
                .al => unreachable,
                .nv => unreachable,
            };
        }
    };

    pub fn toU32(self: Instruction) u32 {
        return switch (self) {
            .move_wide_immediate => |v| @bitCast(u32, v),
            .pc_relative_address => |v| @bitCast(u32, v),
            .load_store_register => |v| @bitCast(u32, v),
            .load_store_register_pair => |v| @bitCast(u32, v),
            .load_literal => |v| @bitCast(u32, v),
            .exception_generation => |v| @bitCast(u32, v),
            .unconditional_branch_register => |v| @bitCast(u32, v),
            .unconditional_branch_immediate => |v| @bitCast(u32, v),
            .no_operation => |v| @bitCast(u32, v),
            .logical_shifted_register => |v| @bitCast(u32, v),
            .add_subtract_immediate => |v| @bitCast(u32, v),
            .add_subtract_shifted_register => |v| @bitCast(u32, v),
            // TODO once packed structs work, this can be refactored
            .conditional_branch => |v| @as(u32, v.cond) | (@as(u32, v.o0) << 4) | (@as(u32, v.imm19) << 5) | (@as(u32, v.o1) << 24) | (@as(u32, v.fixed) << 25),
            .compare_and_branch => |v| @as(u32, v.rt) | (@as(u32, v.imm19) << 5) | (@as(u32, v.op) << 24) | (@as(u32, v.fixed) << 25) | (@as(u32, v.sf) << 31),
            .conditional_select => |v| @as(u32, v.rd) | @as(u32, v.rn) << 5 | @as(u32, v.op2) << 10 | @as(u32, v.cond) << 12 | @as(u32, v.rm) << 16 | @as(u32, v.fixed) << 21 | @as(u32, v.s) << 29 | @as(u32, v.op) << 30 | @as(u32, v.sf) << 31,
        };
    }

    fn moveWideImmediate(
        opc: u2,
        rd: Register,
        imm16: u16,
        shift: u6,
    ) Instruction {
        switch (rd.size()) {
            32 => {
                assert(shift % 16 == 0 and shift <= 16);
                return Instruction{
                    .move_wide_immediate = .{
                        .rd = rd.id(),
                        .imm16 = imm16,
                        .hw = @intCast(u2, shift / 16),
                        .opc = opc,
                        .sf = 0,
                    },
                };
            },
            64 => {
                assert(shift % 16 == 0 and shift <= 48);
                return Instruction{
                    .move_wide_immediate = .{
                        .rd = rd.id(),
                        .imm16 = imm16,
                        .hw = @intCast(u2, shift / 16),
                        .opc = opc,
                        .sf = 1,
                    },
                };
            },
            else => unreachable, // unexpected register size
        }
    }

    fn pcRelativeAddress(rd: Register, imm21: i21, op: u1) Instruction {
        assert(rd.size() == 64);
        const imm21_u = @bitCast(u21, imm21);
        return Instruction{
            .pc_relative_address = .{
                .rd = rd.id(),
                .immlo = @truncate(u2, imm21_u),
                .immhi = @truncate(u19, imm21_u >> 2),
                .op = op,
            },
        };
    }

    /// Represents the offset operand of a load or store instruction.
    /// Data can be loaded from memory with either an immediate offset
    /// or an offset that is stored in some register.
    pub const LoadStoreOffset = union(enum) {
        Immediate: union(enum) {
            PostIndex: i9,
            PreIndex: i9,
            Unsigned: u12,
        },
        Register: struct {
            rm: u5,
            shift: union(enum) {
                Uxtw: u2,
                Lsl: u2,
                Sxtw: u2,
                Sxtx: u2,
            },
        },

        pub const none = LoadStoreOffset{
            .Immediate = .{ .Unsigned = 0 },
        };

        pub fn toU12(self: LoadStoreOffset) u12 {
            return switch (self) {
                .Immediate => |imm_type| switch (imm_type) {
                    .PostIndex => |v| (@intCast(u12, @bitCast(u9, v)) << 2) + 1,
                    .PreIndex => |v| (@intCast(u12, @bitCast(u9, v)) << 2) + 3,
                    .Unsigned => |v| v,
                },
                .Register => |r| switch (r.shift) {
                    .Uxtw => |v| (@intCast(u12, r.rm) << 6) + (@intCast(u12, v) << 2) + 16 + 2050,
                    .Lsl => |v| (@intCast(u12, r.rm) << 6) + (@intCast(u12, v) << 2) + 24 + 2050,
                    .Sxtw => |v| (@intCast(u12, r.rm) << 6) + (@intCast(u12, v) << 2) + 48 + 2050,
                    .Sxtx => |v| (@intCast(u12, r.rm) << 6) + (@intCast(u12, v) << 2) + 56 + 2050,
                },
            };
        }

        pub fn imm(offset: u12) LoadStoreOffset {
            return .{
                .Immediate = .{ .Unsigned = offset },
            };
        }

        pub fn imm_post_index(offset: i9) LoadStoreOffset {
            return .{
                .Immediate = .{ .PostIndex = offset },
            };
        }

        pub fn imm_pre_index(offset: i9) LoadStoreOffset {
            return .{
                .Immediate = .{ .PreIndex = offset },
            };
        }

        pub fn reg(rm: Register) LoadStoreOffset {
            return .{
                .Register = .{
                    .rm = rm.id(),
                    .shift = .{
                        .Lsl = 0,
                    },
                },
            };
        }

        pub fn reg_uxtw(rm: Register, shift: u2) LoadStoreOffset {
            assert(rm.size() == 32 and (shift == 0 or shift == 2));
            return .{
                .Register = .{
                    .rm = rm.id(),
                    .shift = .{
                        .Uxtw = shift,
                    },
                },
            };
        }

        pub fn reg_lsl(rm: Register, shift: u2) LoadStoreOffset {
            assert(rm.size() == 64 and (shift == 0 or shift == 3));
            return .{
                .Register = .{
                    .rm = rm.id(),
                    .shift = .{
                        .Lsl = shift,
                    },
                },
            };
        }

        pub fn reg_sxtw(rm: Register, shift: u2) LoadStoreOffset {
            assert(rm.size() == 32 and (shift == 0 or shift == 2));
            return .{
                .Register = .{
                    .rm = rm.id(),
                    .shift = .{
                        .Sxtw = shift,
                    },
                },
            };
        }

        pub fn reg_sxtx(rm: Register, shift: u2) LoadStoreOffset {
            assert(rm.size() == 64 and (shift == 0 or shift == 3));
            return .{
                .Register = .{
                    .rm = rm.id(),
                    .shift = .{
                        .Sxtx = shift,
                    },
                },
            };
        }
    };

    /// Which kind of load/store to perform
    const LoadStoreVariant = enum {
        /// 32-bit or 64-bit
        str,
        /// 16-bit, zero-extended
        strh,
        /// 8-bit, zero-extended
        strb,
        /// 32-bit or 64-bit
        ldr,
        /// 16-bit, zero-extended
        ldrh,
        /// 8-bit, zero-extended
        ldrb,
    };

    fn loadStoreRegister(
        rt: Register,
        rn: Register,
        offset: LoadStoreOffset,
        variant: LoadStoreVariant,
    ) Instruction {
        const off = offset.toU12();
        const op1: u2 = blk: {
            switch (offset) {
                .Immediate => |imm| switch (imm) {
                    .Unsigned => break :blk 0b01,
                    else => {},
                },
                else => {},
            }
            break :blk 0b00;
        };
        const opc: u2 = switch (variant) {
            .ldr, .ldrh, .ldrb => 0b01,
            .str, .strh, .strb => 0b00,
        };
        return Instruction{
            .load_store_register = .{
                .rt = rt.id(),
                .rn = rn.id(),
                .offset = off,
                .opc = opc,
                .op1 = op1,
                .v = 0,
                .size = blk: {
                    switch (variant) {
                        .ldr, .str => switch (rt.size()) {
                            32 => break :blk 0b10,
                            64 => break :blk 0b11,
                            else => unreachable, // unexpected register size
                        },
                        .ldrh, .strh => break :blk 0b01,
                        .ldrb, .strb => break :blk 0b00,
                    }
                },
            },
        };
    }

    fn loadStoreRegisterPair(
        rt1: Register,
        rt2: Register,
        rn: Register,
        offset: i9,
        encoding: u2,
        load: bool,
    ) Instruction {
        switch (rt1.size()) {
            32 => {
                assert(-256 <= offset and offset <= 252);
                const imm7 = @truncate(u7, @bitCast(u9, offset >> 2));
                return Instruction{
                    .load_store_register_pair = .{
                        .rt1 = rt1.id(),
                        .rn = rn.id(),
                        .rt2 = rt2.id(),
                        .imm7 = imm7,
                        .load = @boolToInt(load),
                        .encoding = encoding,
                        .opc = 0b00,
                    },
                };
            },
            64 => {
                assert(-512 <= offset and offset <= 504);
                const imm7 = @truncate(u7, @bitCast(u9, offset >> 3));
                return Instruction{
                    .load_store_register_pair = .{
                        .rt1 = rt1.id(),
                        .rn = rn.id(),
                        .rt2 = rt2.id(),
                        .imm7 = imm7,
                        .load = @boolToInt(load),
                        .encoding = encoding,
                        .opc = 0b10,
                    },
                };
            },
            else => unreachable, // unexpected register size
        }
    }

    fn loadLiteral(rt: Register, imm19: u19) Instruction {
        return Instruction{
            .load_literal = .{
                .rt = rt.id(),
                .imm19 = imm19,
                .opc = switch (rt.size()) {
                    32 => 0b00,
                    64 => 0b01,
                    else => unreachable, // unexpected register size
                },
            },
        };
    }

    fn exceptionGeneration(
        opc: u3,
        op2: u3,
        ll: u2,
        imm16: u16,
    ) Instruction {
        return Instruction{
            .exception_generation = .{
                .ll = ll,
                .op2 = op2,
                .imm16 = imm16,
                .opc = opc,
            },
        };
    }

    fn unconditionalBranchRegister(
        opc: u4,
        op2: u5,
        op3: u6,
        rn: Register,
        op4: u5,
    ) Instruction {
        assert(rn.size() == 64);

        return Instruction{
            .unconditional_branch_register = .{
                .op4 = op4,
                .rn = rn.id(),
                .op3 = op3,
                .op2 = op2,
                .opc = opc,
            },
        };
    }

    fn unconditionalBranchImmediate(
        op: u1,
        offset: i28,
    ) Instruction {
        return Instruction{
            .unconditional_branch_immediate = .{
                .imm26 = @bitCast(u26, @intCast(i26, offset >> 2)),
                .op = op,
            },
        };
    }

    fn logicalShiftedRegister(
        opc: u2,
        n: u1,
        shift: Shift,
        rd: Register,
        rn: Register,
        rm: Register,
    ) Instruction {
        switch (rd.size()) {
            32 => {
                assert(shift.amount < 32);
                return Instruction{
                    .logical_shifted_register = .{
                        .rd = rd.id(),
                        .rn = rn.id(),
                        .imm6 = shift.amount,
                        .rm = rm.id(),
                        .n = n,
                        .shift = @enumToInt(shift.shift),
                        .opc = opc,
                        .sf = 0b0,
                    },
                };
            },
            64 => {
                return Instruction{
                    .logical_shifted_register = .{
                        .rd = rd.id(),
                        .rn = rn.id(),
                        .imm6 = shift.amount,
                        .rm = rm.id(),
                        .n = n,
                        .shift = @enumToInt(shift.shift),
                        .opc = opc,
                        .sf = 0b1,
                    },
                };
            },
            else => unreachable, // unexpected register size
        }
    }

    fn addSubtractImmediate(
        op: u1,
        s: u1,
        rd: Register,
        rn: Register,
        imm12: u12,
        shift: bool,
    ) Instruction {
        return Instruction{
            .add_subtract_immediate = .{
                .rd = rd.id(),
                .rn = rn.id(),
                .imm12 = imm12,
                .sh = @boolToInt(shift),
                .s = s,
                .op = op,
                .sf = switch (rd.size()) {
                    32 => 0b0,
                    64 => 0b1,
                    else => unreachable, // unexpected register size
                },
            },
        };
    }

    pub const AddSubtractShiftedRegisterShift = enum(u2) { lsl, lsr, asr, _ };

    fn addSubtractShiftedRegister(
        op: u1,
        s: u1,
        shift: AddSubtractShiftedRegisterShift,
        rd: Register,
        rn: Register,
        rm: Register,
        imm6: u6,
    ) Instruction {
        return Instruction{
            .add_subtract_shifted_register = .{
                .rd = rd.id(),
                .rn = rn.id(),
                .imm6 = imm6,
                .rm = rm.id(),
                .shift = @enumToInt(shift),
                .s = s,
                .op = op,
                .sf = switch (rd.size()) {
                    32 => 0b0,
                    64 => 0b1,
                    else => unreachable, // unexpected register size
                },
            },
        };
    }

    fn conditionalBranch(
        o0: u1,
        o1: u1,
        cond: Condition,
        offset: i21,
    ) Instruction {
        assert(offset & 0b11 == 0b00);
        return Instruction{
            .conditional_branch = .{
                .cond = @enumToInt(cond),
                .o0 = o0,
                .imm19 = @bitCast(u19, @intCast(i19, offset >> 2)),
                .o1 = o1,
            },
        };
    }

    fn compareAndBranch(
        op: u1,
        rt: Register,
        offset: i21,
    ) Instruction {
        assert(offset & 0b11 == 0b00);
        return Instruction{
            .compare_and_branch = .{
                .rt = rt.id(),
                .imm19 = @bitCast(u19, @intCast(i19, offset >> 2)),
                .op = op,
                .sf = switch (rt.size()) {
                    32 => 0b0,
                    64 => 0b1,
                    else => unreachable, // unexpected register size
                },
            },
        };
    }

    fn conditionalSelect(
        op2: u2,
        op: u1,
        s: u1,
        rd: Register,
        rn: Register,
        rm: Register,
        cond: Condition,
    ) Instruction {
        return Instruction{
            .conditional_select = .{
                .rd = rd.id(),
                .rn = rn.id(),
                .op2 = op2,
                .cond = @enumToInt(cond),
                .rm = rm.id(),
                .s = s,
                .op = op,
                .sf = switch (rd.size()) {
                    32 => 0b0,
                    64 => 0b1,
                    else => unreachable, // unexpected register size
                },
            },
        };
    }

    // Helper functions for assembly syntax functions

    // Move wide (immediate)

    pub fn movn(rd: Register, imm16: u16, shift: u6) Instruction {
        return moveWideImmediate(0b00, rd, imm16, shift);
    }

    pub fn movz(rd: Register, imm16: u16, shift: u6) Instruction {
        return moveWideImmediate(0b10, rd, imm16, shift);
    }

    pub fn movk(rd: Register, imm16: u16, shift: u6) Instruction {
        return moveWideImmediate(0b11, rd, imm16, shift);
    }

    // PC relative address

    pub fn adr(rd: Register, imm21: i21) Instruction {
        return pcRelativeAddress(rd, imm21, 0b0);
    }

    pub fn adrp(rd: Register, imm21: i21) Instruction {
        return pcRelativeAddress(rd, imm21, 0b1);
    }

    // Load or store register

    pub fn ldrLiteral(rt: Register, literal: u19) Instruction {
        return loadLiteral(rt, literal);
    }

    pub fn ldr(rt: Register, rn: Register, offset: LoadStoreOffset) Instruction {
        return loadStoreRegister(rt, rn, offset, .ldr);
    }

    pub fn ldrh(rt: Register, rn: Register, offset: LoadStoreOffset) Instruction {
        return loadStoreRegister(rt, rn, offset, .ldrh);
    }

    pub fn ldrb(rt: Register, rn: Register, offset: LoadStoreOffset) Instruction {
        return loadStoreRegister(rt, rn, offset, .ldrb);
    }

    pub fn str(rt: Register, rn: Register, offset: LoadStoreOffset) Instruction {
        return loadStoreRegister(rt, rn, offset, .str);
    }

    pub fn strh(rt: Register, rn: Register, offset: LoadStoreOffset) Instruction {
        return loadStoreRegister(rt, rn, offset, .strh);
    }

    pub fn strb(rt: Register, rn: Register, offset: LoadStoreOffset) Instruction {
        return loadStoreRegister(rt, rn, offset, .strb);
    }

    // Load or store pair of registers

    pub const LoadStorePairOffset = struct {
        encoding: enum(u2) {
            PostIndex = 0b01,
            Signed = 0b10,
            PreIndex = 0b11,
        },
        offset: i9,

        pub fn none() LoadStorePairOffset {
            return .{ .encoding = .Signed, .offset = 0 };
        }

        pub fn post_index(imm: i9) LoadStorePairOffset {
            return .{ .encoding = .PostIndex, .offset = imm };
        }

        pub fn pre_index(imm: i9) LoadStorePairOffset {
            return .{ .encoding = .PreIndex, .offset = imm };
        }

        pub fn signed(imm: i9) LoadStorePairOffset {
            return .{ .encoding = .Signed, .offset = imm };
        }
    };

    pub fn ldp(rt1: Register, rt2: Register, rn: Register, offset: LoadStorePairOffset) Instruction {
        return loadStoreRegisterPair(rt1, rt2, rn, offset.offset, @enumToInt(offset.encoding), true);
    }

    pub fn ldnp(rt1: Register, rt2: Register, rn: Register, offset: i9) Instruction {
        return loadStoreRegisterPair(rt1, rt2, rn, offset, 0, true);
    }

    pub fn stp(rt1: Register, rt2: Register, rn: Register, offset: LoadStorePairOffset) Instruction {
        return loadStoreRegisterPair(rt1, rt2, rn, offset.offset, @enumToInt(offset.encoding), false);
    }

    pub fn stnp(rt1: Register, rt2: Register, rn: Register, offset: i9) Instruction {
        return loadStoreRegisterPair(rt1, rt2, rn, offset, 0, false);
    }

    // Exception generation

    pub fn svc(imm16: u16) Instruction {
        return exceptionGeneration(0b000, 0b000, 0b01, imm16);
    }

    pub fn hvc(imm16: u16) Instruction {
        return exceptionGeneration(0b000, 0b000, 0b10, imm16);
    }

    pub fn smc(imm16: u16) Instruction {
        return exceptionGeneration(0b000, 0b000, 0b11, imm16);
    }

    pub fn brk(imm16: u16) Instruction {
        return exceptionGeneration(0b001, 0b000, 0b00, imm16);
    }

    pub fn hlt(imm16: u16) Instruction {
        return exceptionGeneration(0b010, 0b000, 0b00, imm16);
    }

    // Unconditional branch (register)

    pub fn br(rn: Register) Instruction {
        return unconditionalBranchRegister(0b0000, 0b11111, 0b000000, rn, 0b00000);
    }

    pub fn blr(rn: Register) Instruction {
        return unconditionalBranchRegister(0b0001, 0b11111, 0b000000, rn, 0b00000);
    }

    pub fn ret(rn: ?Register) Instruction {
        return unconditionalBranchRegister(0b0010, 0b11111, 0b000000, rn orelse .x30, 0b00000);
    }

    // Unconditional branch (immediate)

    pub fn b(offset: i28) Instruction {
        return unconditionalBranchImmediate(0, offset);
    }

    pub fn bl(offset: i28) Instruction {
        return unconditionalBranchImmediate(1, offset);
    }

    // Nop

    pub fn nop() Instruction {
        return Instruction{ .no_operation = .{} };
    }

    // Logical (shifted register)

    pub fn @"and"(rd: Register, rn: Register, rm: Register, shift: Shift) Instruction {
        return logicalShiftedRegister(0b00, 0b0, shift, rd, rn, rm);
    }

    pub fn bic(rd: Register, rn: Register, rm: Register, shift: Shift) Instruction {
        return logicalShiftedRegister(0b00, 0b1, shift, rd, rn, rm);
    }

    pub fn orr(rd: Register, rn: Register, rm: Register, shift: Shift) Instruction {
        return logicalShiftedRegister(0b01, 0b0, shift, rd, rn, rm);
    }

    pub fn orn(rd: Register, rn: Register, rm: Register, shift: Shift) Instruction {
        return logicalShiftedRegister(0b01, 0b1, shift, rd, rn, rm);
    }

    pub fn eor(rd: Register, rn: Register, rm: Register, shift: Shift) Instruction {
        return logicalShiftedRegister(0b10, 0b0, shift, rd, rn, rm);
    }

    pub fn eon(rd: Register, rn: Register, rm: Register, shift: Shift) Instruction {
        return logicalShiftedRegister(0b10, 0b1, shift, rd, rn, rm);
    }

    pub fn ands(rd: Register, rn: Register, rm: Register, shift: Shift) Instruction {
        return logicalShiftedRegister(0b11, 0b0, shift, rd, rn, rm);
    }

    pub fn bics(rd: Register, rn: Register, rm: Register, shift: Shift) Instruction {
        return logicalShiftedRegister(0b11, 0b1, shift, rd, rn, rm);
    }

    // Add/subtract (immediate)

    pub fn add(rd: Register, rn: Register, imm: u12, shift: bool) Instruction {
        return addSubtractImmediate(0b0, 0b0, rd, rn, imm, shift);
    }

    pub fn adds(rd: Register, rn: Register, imm: u12, shift: bool) Instruction {
        return addSubtractImmediate(0b0, 0b1, rd, rn, imm, shift);
    }

    pub fn sub(rd: Register, rn: Register, imm: u12, shift: bool) Instruction {
        return addSubtractImmediate(0b1, 0b0, rd, rn, imm, shift);
    }

    pub fn subs(rd: Register, rn: Register, imm: u12, shift: bool) Instruction {
        return addSubtractImmediate(0b1, 0b1, rd, rn, imm, shift);
    }

    // Add/subtract (shifted register)

    pub fn addShiftedRegister(
        rd: Register,
        rn: Register,
        rm: Register,
        shift: AddSubtractShiftedRegisterShift,
        imm6: u6,
    ) Instruction {
        return addSubtractShiftedRegister(0b0, 0b0, shift, rd, rn, rm, imm6);
    }

    pub fn addsShiftedRegister(
        rd: Register,
        rn: Register,
        rm: Register,
        shift: AddSubtractShiftedRegisterShift,
        imm6: u6,
    ) Instruction {
        return addSubtractShiftedRegister(0b0, 0b1, shift, rd, rn, rm, imm6);
    }

    pub fn subShiftedRegister(
        rd: Register,
        rn: Register,
        rm: Register,
        shift: AddSubtractShiftedRegisterShift,
        imm6: u6,
    ) Instruction {
        return addSubtractShiftedRegister(0b1, 0b0, shift, rd, rn, rm, imm6);
    }

    pub fn subsShiftedRegister(
        rd: Register,
        rn: Register,
        rm: Register,
        shift: AddSubtractShiftedRegisterShift,
        imm6: u6,
    ) Instruction {
        return addSubtractShiftedRegister(0b1, 0b1, shift, rd, rn, rm, imm6);
    }

    // Conditional branch

    pub fn bCond(cond: Condition, offset: i21) Instruction {
        return conditionalBranch(0b0, 0b0, cond, offset);
    }

    // Compare and branch

    pub fn cbz(rt: Register, offset: i21) Instruction {
        return compareAndBranch(0b0, rt, offset);
    }

    pub fn cbnz(rt: Register, offset: i21) Instruction {
        return compareAndBranch(0b1, rt, offset);
    }

    // Conditional select

    pub fn csel(rd: Register, rn: Register, rm: Register, cond: Condition) Instruction {
        return conditionalSelect(0b00, 0b0, 0b0, rd, rn, rm, cond);
    }

    pub fn csinc(rd: Register, rn: Register, rm: Register, cond: Condition) Instruction {
        return conditionalSelect(0b01, 0b0, 0b0, rd, rn, rm, cond);
    }

    pub fn csinv(rd: Register, rn: Register, rm: Register, cond: Condition) Instruction {
        return conditionalSelect(0b00, 0b1, 0b0, rd, rn, rm, cond);
    }

    pub fn csneg(rd: Register, rn: Register, rm: Register, cond: Condition) Instruction {
        return conditionalSelect(0b01, 0b1, 0b0, rd, rn, rm, cond);
    }
};

test {
    testing.refAllDecls(@This());
}

test "serialize instructions" {
    const Testcase = struct {
        inst: Instruction,
        expected: u32,
    };

    const testcases = [_]Testcase{
        .{ // orr x0, xzr, x1
            .inst = Instruction.orr(.x0, .xzr, .x1, Instruction.Shift.none),
            .expected = 0b1_01_01010_00_0_00001_000000_11111_00000,
        },
        .{ // orn x0, xzr, x1
            .inst = Instruction.orn(.x0, .xzr, .x1, Instruction.Shift.none),
            .expected = 0b1_01_01010_00_1_00001_000000_11111_00000,
        },
        .{ // movz x1, #4
            .inst = Instruction.movz(.x1, 4, 0),
            .expected = 0b1_10_100101_00_0000000000000100_00001,
        },
        .{ // movz x1, #4, lsl 16
            .inst = Instruction.movz(.x1, 4, 16),
            .expected = 0b1_10_100101_01_0000000000000100_00001,
        },
        .{ // movz x1, #4, lsl 32
            .inst = Instruction.movz(.x1, 4, 32),
            .expected = 0b1_10_100101_10_0000000000000100_00001,
        },
        .{ // movz x1, #4, lsl 48
            .inst = Instruction.movz(.x1, 4, 48),
            .expected = 0b1_10_100101_11_0000000000000100_00001,
        },
        .{ // movz w1, #4
            .inst = Instruction.movz(.w1, 4, 0),
            .expected = 0b0_10_100101_00_0000000000000100_00001,
        },
        .{ // movz w1, #4, lsl 16
            .inst = Instruction.movz(.w1, 4, 16),
            .expected = 0b0_10_100101_01_0000000000000100_00001,
        },
        .{ // svc #0
            .inst = Instruction.svc(0),
            .expected = 0b1101_0100_000_0000000000000000_00001,
        },
        .{ // svc #0x80 ; typical on Darwin
            .inst = Instruction.svc(0x80),
            .expected = 0b1101_0100_000_0000000010000000_00001,
        },
        .{ // ret
            .inst = Instruction.ret(null),
            .expected = 0b1101_011_00_10_11111_0000_00_11110_00000,
        },
        .{ // bl #0x10
            .inst = Instruction.bl(0x10),
            .expected = 0b1_00101_00_0000_0000_0000_0000_0000_0100,
        },
        .{ // ldr x2, [x1]
            .inst = Instruction.ldr(.x2, .x1, Instruction.LoadStoreOffset.none),
            .expected = 0b11_111_0_01_01_000000000000_00001_00010,
        },
        .{ // ldr x2, [x1, #1]!
            .inst = Instruction.ldr(.x2, .x1, Instruction.LoadStoreOffset.imm_pre_index(1)),
            .expected = 0b11_111_0_00_01_0_000000001_11_00001_00010,
        },
        .{ // ldr x2, [x1], #-1
            .inst = Instruction.ldr(.x2, .x1, Instruction.LoadStoreOffset.imm_post_index(-1)),
            .expected = 0b11_111_0_00_01_0_111111111_01_00001_00010,
        },
        .{ // ldr x2, [x1], (x3)
            .inst = Instruction.ldr(.x2, .x1, Instruction.LoadStoreOffset.reg(.x3)),
            .expected = 0b11_111_0_00_01_1_00011_011_0_10_00001_00010,
        },
        .{ // ldr x2, label
            .inst = Instruction.ldrLiteral(.x2, 0x1),
            .expected = 0b01_011_0_00_0000000000000000001_00010,
        },
        .{ // ldrh x7, [x4], #0xaa
            .inst = Instruction.ldrh(.x7, .x4, Instruction.LoadStoreOffset.imm_post_index(0xaa)),
            .expected = 0b01_111_0_00_01_0_010101010_01_00100_00111,
        },
        .{ // ldrb x9, [x15, #0xff]!
            .inst = Instruction.ldrb(.x9, .x15, Instruction.LoadStoreOffset.imm_pre_index(0xff)),
            .expected = 0b00_111_0_00_01_0_011111111_11_01111_01001,
        },
        .{ // str x2, [x1]
            .inst = Instruction.str(.x2, .x1, Instruction.LoadStoreOffset.none),
            .expected = 0b11_111_0_01_00_000000000000_00001_00010,
        },
        .{ // str x2, [x1], (x3)
            .inst = Instruction.str(.x2, .x1, Instruction.LoadStoreOffset.reg(.x3)),
            .expected = 0b11_111_0_00_00_1_00011_011_0_10_00001_00010,
        },
        .{ // strh w0, [x1]
            .inst = Instruction.strh(.w0, .x1, Instruction.LoadStoreOffset.none),
            .expected = 0b01_111_0_01_00_000000000000_00001_00000,
        },
        .{ // strb w8, [x9]
            .inst = Instruction.strb(.w8, .x9, Instruction.LoadStoreOffset.none),
            .expected = 0b00_111_0_01_00_000000000000_01001_01000,
        },
        .{ // adr x2, #0x8
            .inst = Instruction.adr(.x2, 0x8),
            .expected = 0b0_00_10000_0000000000000000010_00010,
        },
        .{ // adr x2, -#0x8
            .inst = Instruction.adr(.x2, -0x8),
            .expected = 0b0_00_10000_1111111111111111110_00010,
        },
        .{ // adrp x2, #0x8
            .inst = Instruction.adrp(.x2, 0x8),
            .expected = 0b1_00_10000_0000000000000000010_00010,
        },
        .{ // adrp x2, -#0x8
            .inst = Instruction.adrp(.x2, -0x8),
            .expected = 0b1_00_10000_1111111111111111110_00010,
        },
        .{ // stp x1, x2, [sp, #8]
            .inst = Instruction.stp(.x1, .x2, Register.sp, Instruction.LoadStorePairOffset.signed(8)),
            .expected = 0b10_101_0_010_0_0000001_00010_11111_00001,
        },
        .{ // ldp x1, x2, [sp, #8]
            .inst = Instruction.ldp(.x1, .x2, Register.sp, Instruction.LoadStorePairOffset.signed(8)),
            .expected = 0b10_101_0_010_1_0000001_00010_11111_00001,
        },
        .{ // stp x1, x2, [sp, #-16]!
            .inst = Instruction.stp(.x1, .x2, Register.sp, Instruction.LoadStorePairOffset.pre_index(-16)),
            .expected = 0b10_101_0_011_0_1111110_00010_11111_00001,
        },
        .{ // ldp x1, x2, [sp], #16
            .inst = Instruction.ldp(.x1, .x2, Register.sp, Instruction.LoadStorePairOffset.post_index(16)),
            .expected = 0b10_101_0_001_1_0000010_00010_11111_00001,
        },
        .{ // and x0, x4, x2
            .inst = Instruction.@"and"(.x0, .x4, .x2, .{}),
            .expected = 0b1_00_01010_00_0_00010_000000_00100_00000,
        },
        .{ // and x0, x4, x2, lsl #0x8
            .inst = Instruction.@"and"(.x0, .x4, .x2, .{ .shift = .lsl, .amount = 0x8 }),
            .expected = 0b1_00_01010_00_0_00010_001000_00100_00000,
        },
        .{ // add x0, x10, #10
            .inst = Instruction.add(.x0, .x10, 10, false),
            .expected = 0b1_0_0_100010_0_0000_0000_1010_01010_00000,
        },
        .{ // subs x0, x5, #11, lsl #12
            .inst = Instruction.subs(.x0, .x5, 11, true),
            .expected = 0b1_1_1_100010_1_0000_0000_1011_00101_00000,
        },
        .{ // b.hi #-4
            .inst = Instruction.bCond(.hi, -4),
            .expected = 0b0101010_0_1111111111111111111_0_1000,
        },
        .{ // cbz x10, #40
            .inst = Instruction.cbz(.x10, 40),
            .expected = 0b1_011010_0_0000000000000001010_01010,
        },
        .{ // add x0, x1, x2, lsl #5
            .inst = Instruction.addShiftedRegister(.x0, .x1, .x2, .lsl, 5),
            .expected = 0b1_0_0_01011_00_0_00010_000101_00001_00000,
        },
        .{ // csinc x1, x2, x4, eq
            .inst = Instruction.csinc(.x1, .x2, .x4, .eq),
            .expected = 0b1_0_0_11010100_00100_0000_0_1_00010_00001,
        },
    };

    for (testcases) |case| {
        const actual = case.inst.toU32();
        try testing.expectEqual(case.expected, actual);
    }
}
