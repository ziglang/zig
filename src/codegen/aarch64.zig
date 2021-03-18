const std = @import("std");
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
        return @as(u8, self.id()) + DW.OP_reg0;
    }
};

// zig fmt: on

pub const callee_preserved_regs = [_]Register{
    .x19, .x20, .x21, .x22, .x23,
    .x24, .x25, .x26, .x27, .x28,
};

pub const c_abi_int_param_regs = [_]Register{ .x0, .x1, .x2, .x3, .x4, .x5, .x6, .x7 };
pub const c_abi_int_return_regs = [_]Register{ .x0, .x1, .x2, .x3, .x4, .x5, .x6, .x7 };

test "Register.id" {
    testing.expectEqual(@as(u5, 0), Register.x0.id());
    testing.expectEqual(@as(u5, 0), Register.w0.id());

    testing.expectEqual(@as(u5, 31), Register.xzr.id());
    testing.expectEqual(@as(u5, 31), Register.wzr.id());

    testing.expectEqual(@as(u5, 31), Register.sp.id());
    testing.expectEqual(@as(u5, 31), Register.sp.id());
}

test "Register.size" {
    testing.expectEqual(@as(u7, 64), Register.x19.size());
    testing.expectEqual(@as(u7, 32), Register.w3.size());
}

test "Register.to64/to32" {
    testing.expectEqual(Register.x0, Register.w0.to64());
    testing.expectEqual(Register.x0, Register.x0.to64());

    testing.expectEqual(Register.w3, Register.w3.to32());
    testing.expectEqual(Register.w3, Register.x3.to32());
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
    testing.expectEqual(@as(u5, 0), FloatingPointRegister.b0.id());
    testing.expectEqual(@as(u5, 0), FloatingPointRegister.h0.id());
    testing.expectEqual(@as(u5, 0), FloatingPointRegister.s0.id());
    testing.expectEqual(@as(u5, 0), FloatingPointRegister.d0.id());
    testing.expectEqual(@as(u5, 0), FloatingPointRegister.q0.id());

    testing.expectEqual(@as(u5, 2), FloatingPointRegister.q2.id());
    testing.expectEqual(@as(u5, 31), FloatingPointRegister.d31.id());
}

test "FloatingPointRegister.size" {
    testing.expectEqual(@as(u8, 128), FloatingPointRegister.q1.size());
    testing.expectEqual(@as(u8, 64), FloatingPointRegister.d2.size());
    testing.expectEqual(@as(u8, 32), FloatingPointRegister.s3.size());
    testing.expectEqual(@as(u8, 16), FloatingPointRegister.h4.size());
    testing.expectEqual(@as(u8, 8), FloatingPointRegister.b5.size());
}

test "FloatingPointRegister.toX" {
    testing.expectEqual(FloatingPointRegister.q1, FloatingPointRegister.q1.to128());
    testing.expectEqual(FloatingPointRegister.q2, FloatingPointRegister.b2.to128());
    testing.expectEqual(FloatingPointRegister.q3, FloatingPointRegister.h3.to128());

    testing.expectEqual(FloatingPointRegister.d0, FloatingPointRegister.q0.to64());
    testing.expectEqual(FloatingPointRegister.s1, FloatingPointRegister.d1.to32());
    testing.expectEqual(FloatingPointRegister.h2, FloatingPointRegister.s2.to16());
    testing.expectEqual(FloatingPointRegister.b3, FloatingPointRegister.h3.to8());
}

/// Represents an instruction in the AArch64 instruction set
pub const Instruction = union(enum) {
    MoveWideImmediate: packed struct {
        rd: u5,
        imm16: u16,
        hw: u2,
        fixed: u6 = 0b100101,
        opc: u2,
        sf: u1,
    },
    PCRelativeAddress: packed struct {
        rd: u5,
        immhi: u19,
        fixed: u5 = 0b10000,
        immlo: u2,
        op: u1,
    },
    LoadStoreRegister: packed struct {
        rt: u5,
        rn: u5,
        offset: u12,
        opc: u2,
        op1: u2,
        v: u1,
        fixed: u3 = 0b111,
        size: u2,
    },
    LoadStorePairOfRegisters: packed struct {
        rt1: u5,
        rn: u5,
        rt2: u5,
        imm7: u7,
        load: u1,
        encoding: u2,
        fixed: u5 = 0b101_0_0,
        opc: u2,
    },
    LoadLiteral: packed struct {
        rt: u5,
        imm19: u19,
        fixed: u6 = 0b011_0_00,
        opc: u2,
    },
    ExceptionGeneration: packed struct {
        ll: u2,
        op2: u3,
        imm16: u16,
        opc: u3,
        fixed: u8 = 0b1101_0100,
    },
    UnconditionalBranchRegister: packed struct {
        op4: u5,
        rn: u5,
        op3: u6,
        op2: u5,
        opc: u4,
        fixed: u7 = 0b1101_011,
    },
    UnconditionalBranchImmediate: packed struct {
        imm26: u26,
        fixed: u5 = 0b00101,
        op: u1,
    },
    NoOperation: packed struct {
        fixed: u32 = 0b1101010100_0_00_011_0010_0000_000_11111,
    },
    LogicalShiftedRegister: packed struct {
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
    AddSubtractImmediate: packed struct {
        rd: u5,
        rn: u5,
        imm12: u12,
        sh: u1,
        fixed: u6 = 0b100010,
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

    pub fn toU32(self: Instruction) u32 {
        return switch (self) {
            .MoveWideImmediate => |v| @bitCast(u32, v),
            .PCRelativeAddress => |v| @bitCast(u32, v),
            .LoadStoreRegister => |v| @bitCast(u32, v),
            .LoadStorePairOfRegisters => |v| @bitCast(u32, v),
            .LoadLiteral => |v| @bitCast(u32, v),
            .ExceptionGeneration => |v| @bitCast(u32, v),
            .UnconditionalBranchRegister => |v| @bitCast(u32, v),
            .UnconditionalBranchImmediate => |v| @bitCast(u32, v),
            .NoOperation => |v| @bitCast(u32, v),
            .LogicalShiftedRegister => |v| @bitCast(u32, v),
            .AddSubtractImmediate => |v| @bitCast(u32, v),
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
                    .MoveWideImmediate = .{
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
                    .MoveWideImmediate = .{
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
            .PCRelativeAddress = .{
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

    fn loadStoreRegister(rt: Register, rn: Register, offset: LoadStoreOffset, load: bool) Instruction {
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
        const opc: u2 = if (load) 0b01 else 0b00;
        switch (rt.size()) {
            32 => {
                return Instruction{
                    .LoadStoreRegister = .{
                        .rt = rt.id(),
                        .rn = rn.id(),
                        .offset = offset.toU12(),
                        .opc = opc,
                        .op1 = op1,
                        .v = 0,
                        .size = 0b10,
                    },
                };
            },
            64 => {
                return Instruction{
                    .LoadStoreRegister = .{
                        .rt = rt.id(),
                        .rn = rn.id(),
                        .offset = offset.toU12(),
                        .opc = opc,
                        .op1 = op1,
                        .v = 0,
                        .size = 0b11,
                    },
                };
            },
            else => unreachable, // unexpected register size
        }
    }

    fn loadStorePairOfRegisters(
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
                    .LoadStorePairOfRegisters = .{
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
                    .LoadStorePairOfRegisters = .{
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
        switch (rt.size()) {
            32 => {
                return Instruction{
                    .LoadLiteral = .{
                        .rt = rt.id(),
                        .imm19 = imm19,
                        .opc = 0b00,
                    },
                };
            },
            64 => {
                return Instruction{
                    .LoadLiteral = .{
                        .rt = rt.id(),
                        .imm19 = imm19,
                        .opc = 0b01,
                    },
                };
            },
            else => unreachable, // unexpected register size
        }
    }

    fn exceptionGeneration(
        opc: u3,
        op2: u3,
        ll: u2,
        imm16: u16,
    ) Instruction {
        return Instruction{
            .ExceptionGeneration = .{
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
            .UnconditionalBranchRegister = .{
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
            .UnconditionalBranchImmediate = .{
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
                    .LogicalShiftedRegister = .{
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
                    .LogicalShiftedRegister = .{
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
            .AddSubtractImmediate = .{
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

    pub const LdrArgs = union(enum) {
        register: struct {
            rn: Register,
            offset: LoadStoreOffset = LoadStoreOffset.none,
        },
        literal: u19,
    };

    pub fn ldr(rt: Register, args: LdrArgs) Instruction {
        switch (args) {
            .register => |info| return loadStoreRegister(rt, info.rn, info.offset, true),
            .literal => |literal| return loadLiteral(rt, literal),
        }
    }

    pub const StrArgs = struct {
        offset: LoadStoreOffset = LoadStoreOffset.none,
    };

    pub fn str(rt: Register, rn: Register, args: StrArgs) Instruction {
        return loadStoreRegister(rt, rn, args.offset, false);
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
        return loadStorePairOfRegisters(rt1, rt2, rn, offset.offset, @enumToInt(offset.encoding), true);
    }

    pub fn ldnp(rt1: Register, rt2: Register, rn: Register, offset: i9) Instruction {
        return loadStorePairOfRegisters(rt1, rt2, rn, offset, 0, true);
    }

    pub fn stp(rt1: Register, rt2: Register, rn: Register, offset: LoadStorePairOffset) Instruction {
        return loadStorePairOfRegisters(rt1, rt2, rn, offset.offset, @enumToInt(offset.encoding), false);
    }

    pub fn stnp(rt1: Register, rt2: Register, rn: Register, offset: i9) Instruction {
        return loadStorePairOfRegisters(rt1, rt2, rn, offset, 0, false);
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
        return Instruction{ .NoOperation = .{} };
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
            .inst = Instruction.ldr(.x2, .{ .register = .{ .rn = .x1 } }),
            .expected = 0b11_111_0_01_01_000000000000_00001_00010,
        },
        .{ // ldr x2, [x1, #1]!
            .inst = Instruction.ldr(.x2, .{ .register = .{ .rn = .x1, .offset = Instruction.LoadStoreOffset.imm_pre_index(1) } }),
            .expected = 0b11_111_0_00_01_0_000000001_11_00001_00010,
        },
        .{ // ldr x2, [x1], #-1
            .inst = Instruction.ldr(.x2, .{ .register = .{ .rn = .x1, .offset = Instruction.LoadStoreOffset.imm_post_index(-1) } }),
            .expected = 0b11_111_0_00_01_0_111111111_01_00001_00010,
        },
        .{ // ldr x2, [x1], (x3)
            .inst = Instruction.ldr(.x2, .{ .register = .{ .rn = .x1, .offset = Instruction.LoadStoreOffset.reg(.x3) } }),
            .expected = 0b11_111_0_00_01_1_00011_011_0_10_00001_00010,
        },
        .{ // ldr x2, label
            .inst = Instruction.ldr(.x2, .{ .literal = 0x1 }),
            .expected = 0b01_011_0_00_0000000000000000001_00010,
        },
        .{ // str x2, [x1]
            .inst = Instruction.str(.x2, .x1, .{}),
            .expected = 0b11_111_0_01_00_000000000000_00001_00010,
        },
        .{ // str x2, [x1], (x3)
            .inst = Instruction.str(.x2, .x1, .{ .offset = Instruction.LoadStoreOffset.reg(.x3) }),
            .expected = 0b11_111_0_00_00_1_00011_011_0_10_00001_00010,
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
    };

    for (testcases) |case| {
        const actual = case.inst.toU32();
        testing.expectEqual(case.expected, actual);
    }
}
