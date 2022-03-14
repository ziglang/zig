const std = @import("std");
const DW = std.dwarf;
const assert = std.debug.assert;
const testing = std.testing;

/// General purpose registers in the SPARCv9 instruction set
pub const Register = enum(u6) {
    // zig fmt: off
    g0,    g1,    g2,    g3,    g4,    g5,    g6,    g7,
    o0,    o1,    o2,    o3,    o4,    o5,    o6,    o7,
    l0,    l1,    l2,    l3,    l4,    l5,    l6,    l7,
  @"i0", @"i1", @"i2", @"i3", @"i4", @"i5", @"i6", @"i7",

    sp = 46, // stack pointer (o6)
    fp = 62, // frame pointer (i6)
    // zig fmt: on

    pub fn id(self: Register) u5 {
        return @truncate(u5, @enumToInt(self));
    }

    pub fn enc(self: Register) u5 {
        // For integer registers, enc() == id().
        return self.id();
    }

    pub fn dwarfLocOp(reg: Register) u8 {
        return @as(u8, reg.id()) + DW.OP.reg0;
    }
};

test "Register.id" {
    // SP
    try testing.expectEqual(@as(u5, 14), Register.o6.id());
    try testing.expectEqual(Register.o6.id(), Register.sp.id());

    // FP
    try testing.expectEqual(@as(u5, 30), Register.@"i6".id());
    try testing.expectEqual(Register.@"i6".id(), Register.fp.id());

    // x0
    try testing.expectEqual(@as(u5, 0), Register.g0.id());
    try testing.expectEqual(@as(u5, 8), Register.o0.id());
    try testing.expectEqual(@as(u5, 16), Register.l0.id());
    try testing.expectEqual(@as(u5, 24), Register.@"i0".id());
}

test "Register.enc" {
    // x0
    try testing.expectEqual(@as(u5, 0), Register.g0.enc());
    try testing.expectEqual(@as(u5, 8), Register.o0.enc());
    try testing.expectEqual(@as(u5, 16), Register.l0.enc());
    try testing.expectEqual(@as(u5, 24), Register.@"i0".enc());

    // For integer registers, enc() == id().
    try testing.expectEqual(Register.g0.enc(), Register.g0.id());
    try testing.expectEqual(Register.o0.enc(), Register.o0.id());
    try testing.expectEqual(Register.l0.enc(), Register.l0.id());
    try testing.expectEqual(Register.@"i0".enc(), Register.@"i0".id());
}

/// Scalar floating point registers in the SPARCv9 instruction set
pub const FloatingPointRegister = enum(u7) {
    // SPARCv9 has 64 f32 registers, 32 f64 registers, and 16 f128 registers,
    // which are aliased in this way:
    //
    //      |    %d0    |    %d2    |
    // %q0  | %f0 | %f1 | %f2 | %f3 |
    //      |    %d4    |    %d6    |
    // %q4  | %f4 | %f5 | %f6 | %f7 |
    // ...
    //      |    %d60     |    %d62     |
    // %q60 | %f60 | %f61 | %f62 | %f63 |
    //
    // Though, since the instructions uses five-bit addressing, only %f0-%f31
    // is usable with f32 instructions.

    // zig fmt: off

    // 32-bit registers
     @"f0",  @"f1",  @"f2",  @"f3",  @"f4",  @"f5",  @"f6",  @"f7",
     @"f8",  @"f9", @"f10", @"f11", @"f12", @"f13", @"f14", @"f15",
    @"f16", @"f17", @"f18", @"f19", @"f20", @"f21", @"f22", @"f23",
    @"f24", @"f25", @"f26", @"f27", @"f28", @"f29", @"f30", @"f31",

    // 64-bit registers
     d0,  d2,  d4,  d6,  d8, d10, d12, d14,
    d16, d18, d20, d22, d24, d26, d28, d30,
    d32, d34, d36, d38, d40, d42, d44, d46,
    d48, d50, d52, d54, d56, d58, d60, d62,

    // 128-bit registers
     q0,  q4,  q8, q12, q16, q20, q24, q28,
    q32, q36, q40, q44, q48, q52, q56, q60,
    // zig fmt: on

    pub fn id(self: FloatingPointRegister) u6 {
        return switch (self.size()) {
            32 => @truncate(u6, @enumToInt(self)),
            64 => @truncate(u6, (@enumToInt(self) - 32) * 2),
            128 => @truncate(u6, (@enumToInt(self) - 64) * 4),
            else => unreachable,
        };
    }

    pub fn enc(self: FloatingPointRegister) u5 {
        // Floating point registers use an encoding scheme to map from the 6-bit
        // ID to 5-bit encoded value.
        // (See section 5.1.4.1 of SPARCv9 ISA specification)

        const reg_id = self.id();
        return @truncate(u5, reg_id | (reg_id >> 5));
    }

    /// Returns the bit-width of the register.
    pub fn size(self: FloatingPointRegister) u8 {
        return switch (@enumToInt(self)) {
            0...31 => 32,
            32...63 => 64,
            64...79 => 128,
            else => unreachable,
        };
    }
};

test "FloatingPointRegister.id" {
    // Low region
    try testing.expectEqual(@as(u6, 0), FloatingPointRegister.q0.id());
    try testing.expectEqual(FloatingPointRegister.q0.id(), FloatingPointRegister.d0.id());
    try testing.expectEqual(FloatingPointRegister.d0.id(), FloatingPointRegister.@"f0".id());

    try testing.expectEqual(@as(u6, 28), FloatingPointRegister.q28.id());
    try testing.expectEqual(FloatingPointRegister.q28.id(), FloatingPointRegister.d28.id());
    try testing.expectEqual(FloatingPointRegister.d28.id(), FloatingPointRegister.@"f28".id());

    // High region
    try testing.expectEqual(@as(u6, 32), FloatingPointRegister.q32.id());
    try testing.expectEqual(FloatingPointRegister.q32.id(), FloatingPointRegister.d32.id());

    try testing.expectEqual(@as(u6, 60), FloatingPointRegister.q60.id());
    try testing.expectEqual(FloatingPointRegister.q60.id(), FloatingPointRegister.d60.id());
}

test "FloatingPointRegister.enc" {
    // f registers
    try testing.expectEqual(@as(u5, 0), FloatingPointRegister.@"f0".enc());
    try testing.expectEqual(@as(u5, 1), FloatingPointRegister.@"f1".enc());
    try testing.expectEqual(@as(u5, 31), FloatingPointRegister.@"f31".enc());

    // d registers
    try testing.expectEqual(@as(u5, 0), FloatingPointRegister.d0.enc());
    try testing.expectEqual(@as(u5, 1), FloatingPointRegister.d32.enc());
    try testing.expectEqual(@as(u5, 31), FloatingPointRegister.d62.enc());

    // q registers
    try testing.expectEqual(@as(u5, 0), FloatingPointRegister.q0.enc());
    try testing.expectEqual(@as(u5, 1), FloatingPointRegister.q32.enc());
    try testing.expectEqual(@as(u5, 29), FloatingPointRegister.q60.enc());
}

/// Represents an instruction in the SPARCv9 instruction set
pub const Instruction = union(enum) {
    // Some of the instruction formats have several minor formats, here I
    // name them with letters since there's no official naming scheme.
    // TODO: need to rename the minor formats to a more descriptive name.

    // Format 1 (op = 1): CALL
    format_1: packed struct {
        op: u2 = 0b01,
        disp30: u30,
    },

    // Format 2 (op = 0): SETHI & Branches (Bicc, BPcc, BPr, FBfcc, FBPfcc)
    format_2a: packed struct {
        op: u2 = 0b00,
        rd: u5,
        op2: u3,
        imm22: u22,
    },
    format_2b: packed struct {
        op: u2 = 0b00,
        a: u1,
        cond: u4,
        op2: u3,
        disp22: u22,
    },
    format_2c: packed struct {
        op: u2 = 0b00,
        a: u1,
        cond: u4,
        op2: u3,
        cc1: u1,
        cc0: u1,
        p: u1,
        disp19: u19,
    },
    format_2d: packed struct {
        op: u2 = 0b00,
        a: u1,
        fixed: u1 = 0b0,
        rcond: u3,
        op2: u3,
        d16hi: u2,
        p: u1,
        rs1: u5,
        d16lo: u14,
    },

    // Format 3 (op = 2 or 3): Arithmetic, Logical, MOVr, MEMBAR, Load, and Store
    format_3a: packed struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b0,
        reserved: u8 = 0b00000000,
        rs2: u5,
    },
    format_3b: packed struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b1,
        simm13: u13,
    },
    format_3c: packed struct {
        op: u2,
        reserved1: u5 = 0b00000,
        op3: u6,
        rs1: u5,
        i: u1 = 0b0,
        reserved2: u8 = 0b00000000,
        rs2: u5,
    },
    format_3d: packed struct {
        op: u2,
        reserved: u5 = 0b00000,
        op3: u6,
        rs1: u5,
        i: u1 = 0b1,
        simm13: u13,
    },
    format_3e: packed struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b0,
        rcond: u3,
        reserved: u5 = 0b00000,
        rs2: u5,
    },
    format_3f: packed struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b1,
        rcond: u3,
        simm10: u10,
    },
    format_3g: packed struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b1,
        reserved: u8 = 0b00000000,
        rs2: u5,
    },
    format_3h: packed struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b1,
        reserved: u6,
        cmask: u3,
        mmask: u4,
    },
    format_3i: packed struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b0,
        imm_asi: u8,
        rs2: u5,
    },
    format_3j: packed struct {
        op: u2,
        impl_dep1: u5,
        op3: u6,
        impl_dep2: u19,
    },
    format_3k: packed struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b0,
        x: u1,
        reserved: u7 = 0b0000000,
        rs2: u5,
    },
    format_3l: packed struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b1,
        x: u1 = 0b0,
        reserved: u7 = 0b0000000,
        shcnt32: u5,
    },
    format_3m: packed struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b1,
        x: u1 = 0b1,
        reserved: u6 = 0b000000,
        shcnt64: u6,
    },
    format_3n: packed struct {
        op: u2,
        rd: u5,
        op3: u6,
        reserved: u5 = 0b00000,
        opf: u9,
        rs2: u5,
    },
    format_3o: packed struct {
        op: u2,
        fixed: u3 = 0b000,
        cc1: u1,
        cc0: i1,
        op3: u6,
        opf: u9,
        rs2: u5,
    },
    format_3p: packed struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        opf: u9,
        rs2: u5,
    },
    format_3q: packed struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        reserved: u14 = 0b00000000000000,
    },
    format_3r: packed struct {
        op: u2,
        fcn: u5,
        op3: u6,
        reserved: u19 = 0b0000000000000000000,
    },
    format_3s: packed struct {
        op: u2,
        rd: u5,
        op3: u6,
        reserved: u19 = 0b0000000000000000000,
    },

    //Format 4 (op = 2): MOVcc, FMOVr, FMOVcc, and Tcc
    format_4a: packed struct {
        op: u2 = 0b10,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b0,
        cc1: u1,
        cc0: u1,
        reserved: u6 = 0b000000,
        rs2: u5,
    },
    format_4b: packed struct {
        op: u2 = 0b10,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b1,
        cc1: u1,
        cc0: u1,
        simm11: u11,
    },
    format_4c: packed struct {
        op: u2 = 0b10,
        rd: u5,
        op3: u6,
        cc2: u1,
        cond: u4,
        i: u1 = 0b0,
        cc1: u1,
        cc0: u1,
        reserved: u6 = 0b000000,
        rs2: u5,
    },
    format_4d: packed struct {
        op: u2 = 0b10,
        rd: u5,
        op3: u6,
        cc2: u1,
        cond: u4,
        i: u1 = 0b1,
        cc1: u1,
        cc0: u1,
        simm11: u11,
    },
    format_4e: packed struct {
        op: u2 = 0b10,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b1,
        cc1: u1,
        cc0: u1,
        reserved: u4 = 0b0000,
        sw_trap: u7,
    },
    format_4f: packed struct {
        op: u2 = 0b10,
        rd: u5,
        op3: u6,
        rs1: u5,
        fixed: u1 = 0b0,
        rcond: u3,
        opf_low: u5,
        rs2: u5,
    },
    format_4g: packed struct {
        op: u2 = 0b10,
        rd: u5,
        op3: u6,
        fixed: u1 = 0b0,
        cond: u4,
        opf_cc: u3,
        opf_low: u6,
        rs2: u5,
    },

    pub const CCR = enum(u3) {
        fcc0,
        fcc1,
        fcc2,
        fcc3,
        icc,
        reserved1,
        xcc,
        reserved2,
    };

    pub const RCondition = enum(u3) {
        reserved1,
        eq_zero,
        le_zero,
        lt_zero,
        reserved,
        ne_zero,
        gt_zero,
        ge_zero,
    };

    // TODO: Need to define an enum for `cond` values
    // This is kinda challenging since the cond values have different meanings
    // depending on whether it's operating on integer or FP CCR.
    pub const Condition = u4;

    pub fn toU32(self: Instruction) u32 {
        return @bitCast(u32, self);
    }

    fn format1(disp: i32) Instruction {
        // In SPARC, branch target needs to be aligned to 4 bytes.
        assert(disp % 4 == 0);

        // Discard the last two bits since those are implicitly zero.
        const udisp = @truncate(u30, @bitCast(u32, disp) >> 2);
        return Instruction{ .format_1 = .{
            .disp30 = udisp,
        } };
    }

    fn format2a(rd: Register, op2: u3, imm: i22) Instruction {
        return Instruction{
            .format_2a = .{
                .rd = rd.enc(),
                .op2 = op2,
                .imm22 = @bitCast(u22, imm),
            },
        };
    }

    fn format2b(annul: bool, cond: Condition, op2: u3, disp: i24) Instruction {
        // In SPARC, branch target needs to be aligned to 4 bytes.
        assert(disp % 4 == 0);

        // Discard the last two bits since those are implicitly zero.
        const udisp = @truncate(u22, @bitCast(u24, disp) >> 2);
        return Instruction{
            .format_2b = .{
                .a = @boolToInt(annul),
                .cond = cond,
                .op2 = op2,
                .disp22 = udisp,
            },
        };
    }

    fn format2c(annul: bool, cond: Condition, op2: u3, ccr: CCR, pt: bool, disp: i21) Instruction {
        // In SPARC, branch target needs to be aligned to 4 bytes.
        assert(disp % 4 == 0);

        // Discard the last two bits since those are implicitly zero.
        const udisp = @truncate(u19, @bitCast(u21, disp) >> 2);

        const ccr_cc1 = @truncate(u1, @enumToInt(ccr) >> 1);
        const ccr_cc0 = @truncate(u1, @enumToInt(ccr));
        return Instruction{
            .format_2c = .{
                .a = @boolToInt(annul),
                .cond = cond,
                .op2 = op2,
                .cc1 = ccr_cc1,
                .cc0 = ccr_cc0,
                .p = @boolToInt(pt),
                .disp19 = udisp,
            },
        };
    }

    fn format2d(annul: bool, rcond: RCondition, op2: u3, pt: bool, rs1: Register, disp: i18) Instruction {
        // In SPARC, branch target needs to be aligned to 4 bytes.
        assert(disp % 4 == 0);

        // Discard the last two bits since those are implicitly zero,
        // and split it into low and high parts.
        const udisp = @truncate(u16, @bitCast(u18, disp) >> 2);
        const udisp_hi = @truncate(u2, (udisp & 0b1100_0000_0000_0000) >> 14);
        const udisp_lo = @truncate(u14, udisp & 0b0011_1111_1111_1111);
        return Instruction{
            .format_2a = .{
                .a = @boolToInt(annul),
                .rcond = @enumToInt(rcond),
                .op2 = op2,
                .p = @boolToInt(pt),
                .rs1 = rs1.enc(),
                .d16hi = udisp_hi,
                .d16lo = udisp_lo,
            },
        };
    }

    fn format4a(rd: Register, op3: u6, rs1: Register, cc: CCR, rs2: Register) Instruction {
        const ccr_cc1 = @truncate(u1, @enumToInt(cc) >> 1);
        const ccr_cc0 = @truncate(u1, @enumToInt(cc));
        return Instruction{
            .format4a = .{
                .rd = rd.enc(),
                .op3 = op3,
                .rs1 = rs1.enc(),
                .cc1 = ccr_cc1,
                .cc0 = ccr_cc0,
                .rs2 = rs2.enc(),
            },
        };
    }

    fn format4b(rd: Register, op3: u6, rs1: Register, cc: CCR, imm: i11) Instruction {
        const ccr_cc1 = @truncate(u1, @enumToInt(cc) >> 1);
        const ccr_cc0 = @truncate(u1, @enumToInt(cc));
        return Instruction{
            .format4b = .{
                .rd = rd.enc(),
                .op3 = op3,
                .rs1 = rs1.enc(),
                .cc1 = ccr_cc1,
                .cc0 = ccr_cc0,
                .simm11 = @bitCast(u11, imm),
            },
        };
    }

    fn format4c(rd: Register, op3: u6, cc: CCR, cond: Condition, rs2: Register) Instruction {
        const ccr_cc2 = @truncate(u1, @enumToInt(cc) >> 2);
        const ccr_cc1 = @truncate(u1, @enumToInt(cc) >> 1);
        const ccr_cc0 = @truncate(u1, @enumToInt(cc));
        return Instruction{
            .format4c = .{
                .rd = rd.enc(),
                .op3 = op3,
                .cc2 = ccr_cc2,
                .cond = cond,
                .cc1 = ccr_cc1,
                .cc0 = ccr_cc0,
                .rs2 = rs2.enc(),
            },
        };
    }

    fn format4d(rd: Register, op3: u6, cc: CCR, cond: Condition, imm: i11) Instruction {
        const ccr_cc2 = @truncate(u1, @enumToInt(cc) >> 2);
        const ccr_cc1 = @truncate(u1, @enumToInt(cc) >> 1);
        const ccr_cc0 = @truncate(u1, @enumToInt(cc));
        return Instruction{
            .format4d = .{
                .rd = rd.enc(),
                .op3 = op3,
                .cc2 = ccr_cc2,
                .cond = cond,
                .cc1 = ccr_cc1,
                .cc0 = ccr_cc0,
                .simm11 = @bitCast(u11, imm),
            },
        };
    }

    fn format4e(rd: Register, op3: u6, rs1: Register, cc: CCR, sw_trap: u7) Instruction {
        const ccr_cc1 = @truncate(u1, @enumToInt(cc) >> 1);
        const ccr_cc0 = @truncate(u1, @enumToInt(cc));
        return Instruction{
            .format4e = .{
                .rd = rd.enc(),
                .op3 = op3,
                .rs1 = rs1.enc(),
                .cc1 = ccr_cc1,
                .cc0 = ccr_cc0,
                .sw_trap = sw_trap,
            },
        };
    }

    fn format4f(rd: Register, op3: u6, rs1: Register, rcond: RCondition, opf_low: u5, rs2: Register) Instruction {
        return Instruction{
            .format4f = .{
                .rd = rd.enc(),
                .op3 = op3,
                .rs1 = rs1.enc(),
                .rcond = @enumToInt(rcond),
                .opf_low = opf_low,
                .rs2 = rs2.enc(),
            },
        };
    }

    fn format4g(rd: Register, op3: u6, cond: Condition, opf_cc: u3, opf_low: u6, rs2: Register) Instruction {
        return Instruction{
            .format4g = .{
                .rd = rd.enc(),
                .op3 = op3,
                .cond = cond,
                .opf_cc = opf_cc,
                .opf_low = opf_low,
                .rs2 = rs2.enc(),
            },
        };
    }
};
