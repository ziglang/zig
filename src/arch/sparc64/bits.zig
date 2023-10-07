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
        return @as(u5, @truncate(@intFromEnum(self)));
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
    try testing.expectEqual(@as(u5, 30), Register.i6.id());
    try testing.expectEqual(Register.i6.id(), Register.fp.id());

    // x0
    try testing.expectEqual(@as(u5, 0), Register.g0.id());
    try testing.expectEqual(@as(u5, 8), Register.o0.id());
    try testing.expectEqual(@as(u5, 16), Register.l0.id());
    try testing.expectEqual(@as(u5, 24), Register.i0.id());
}

test "Register.enc" {
    // x0
    try testing.expectEqual(@as(u5, 0), Register.g0.enc());
    try testing.expectEqual(@as(u5, 8), Register.o0.enc());
    try testing.expectEqual(@as(u5, 16), Register.l0.enc());
    try testing.expectEqual(@as(u5, 24), Register.i0.enc());

    // For integer registers, enc() == id().
    try testing.expectEqual(Register.g0.enc(), Register.g0.id());
    try testing.expectEqual(Register.o0.enc(), Register.o0.id());
    try testing.expectEqual(Register.l0.enc(), Register.l0.id());
    try testing.expectEqual(Register.i0.enc(), Register.i0.id());
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
            32 => @as(u6, @truncate(@intFromEnum(self))),
            64 => @as(u6, @truncate((@intFromEnum(self) - 32) * 2)),
            128 => @as(u6, @truncate((@intFromEnum(self) - 64) * 4)),
            else => unreachable,
        };
    }

    pub fn enc(self: FloatingPointRegister) u5 {
        // Floating point registers use an encoding scheme to map from the 6-bit
        // ID to 5-bit encoded value.
        // (See section 5.1.4.1 of SPARCv9 ISA specification)

        const reg_id = self.id();
        return @as(u5, @truncate(reg_id | (reg_id >> 5)));
    }

    /// Returns the bit-width of the register.
    pub fn size(self: FloatingPointRegister) u8 {
        return switch (@intFromEnum(self)) {
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
    try testing.expectEqual(FloatingPointRegister.d0.id(), FloatingPointRegister.f0.id());

    try testing.expectEqual(@as(u6, 28), FloatingPointRegister.q28.id());
    try testing.expectEqual(FloatingPointRegister.q28.id(), FloatingPointRegister.d28.id());
    try testing.expectEqual(FloatingPointRegister.d28.id(), FloatingPointRegister.f28.id());

    // High region
    try testing.expectEqual(@as(u6, 32), FloatingPointRegister.q32.id());
    try testing.expectEqual(FloatingPointRegister.q32.id(), FloatingPointRegister.d32.id());

    try testing.expectEqual(@as(u6, 60), FloatingPointRegister.q60.id());
    try testing.expectEqual(FloatingPointRegister.q60.id(), FloatingPointRegister.d60.id());
}

test "FloatingPointRegister.enc" {
    // f registers
    try testing.expectEqual(@as(u5, 0), FloatingPointRegister.f0.enc());
    try testing.expectEqual(@as(u5, 1), FloatingPointRegister.f1.enc());
    try testing.expectEqual(@as(u5, 31), FloatingPointRegister.f31.enc());

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

    // I am using regular structs instead of packed ones to avoid
    // endianness-dependent behavior when constructing the actual
    // assembly instructions.
    // See also: https://github.com/ziglang/zig/issues/10113
    // TODO: change it back to packed structs once the issue is resolved.

    // Format 1 (op = 1): CALL
    format_1: struct {
        op: u2 = 0b01,
        disp30: u30,
    },

    // Format 2 (op = 0): SETHI & Branches (Bicc, BPcc, BPr, FBfcc, FBPfcc)
    format_2a: struct {
        op: u2 = 0b00,
        rd: u5,
        op2: u3,
        imm22: u22,
    },
    format_2b: struct {
        op: u2 = 0b00,
        a: u1,
        cond: u4,
        op2: u3,
        disp22: u22,
    },
    format_2c: struct {
        op: u2 = 0b00,
        a: u1,
        cond: u4,
        op2: u3,
        cc1: u1,
        cc0: u1,
        p: u1,
        disp19: u19,
    },
    format_2d: struct {
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
    format_3a: struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b0,
        reserved: u8 = 0b00000000,
        rs2: u5,
    },
    format_3b: struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b1,
        simm13: u13,
    },
    format_3c: struct {
        op: u2,
        reserved1: u5 = 0b00000,
        op3: u6,
        rs1: u5,
        i: u1 = 0b0,
        reserved2: u8 = 0b00000000,
        rs2: u5,
    },
    format_3d: struct {
        op: u2,
        reserved: u5 = 0b00000,
        op3: u6,
        rs1: u5,
        i: u1 = 0b1,
        simm13: u13,
    },
    format_3e: struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b0,
        rcond: u3,
        reserved: u5 = 0b00000,
        rs2: u5,
    },
    format_3f: struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b1,
        rcond: u3,
        simm10: u10,
    },
    format_3g: struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        // See Errata 58 of SPARCv9 specification
        // https://sparc.org/errata-for-v9/#58
        i: u1 = 0b1,
        reserved: u8 = 0b00000000,
        rs2: u5,
    },
    format_3h: struct {
        op: u2 = 0b10,
        fixed1: u5 = 0b00000,
        op3: u6 = 0b101000,
        fixed2: u5 = 0b01111,
        i: u1 = 0b1,
        reserved: u6 = 0b000000,
        cmask: u3,
        mmask: u4,
    },
    format_3i: struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b0,
        imm_asi: u8,
        rs2: u5,
    },
    format_3j: struct {
        op: u2,
        impl_dep1: u5,
        op3: u6,
        impl_dep2: u19,
    },
    format_3k: struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b0,
        x: u1,
        reserved: u7 = 0b0000000,
        rs2: u5,
    },
    format_3l: struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b1,
        x: u1 = 0b0,
        reserved: u7 = 0b0000000,
        shcnt32: u5,
    },
    format_3m: struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b1,
        x: u1 = 0b1,
        reserved: u6 = 0b000000,
        shcnt64: u6,
    },
    format_3n: struct {
        op: u2,
        rd: u5,
        op3: u6,
        reserved: u5 = 0b00000,
        opf: u9,
        rs2: u5,
    },
    format_3o: struct {
        op: u2,
        fixed: u3 = 0b000,
        cc1: u1,
        cc0: u1,
        op3: u6,
        rs1: u5,
        opf: u9,
        rs2: u5,
    },
    format_3p: struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        opf: u9,
        rs2: u5,
    },
    format_3q: struct {
        op: u2,
        rd: u5,
        op3: u6,
        rs1: u5,
        reserved: u14 = 0b00000000000000,
    },
    format_3r: struct {
        op: u2,
        fcn: u5,
        op3: u6,
        reserved: u19 = 0b0000000000000000000,
    },
    format_3s: struct {
        op: u2,
        rd: u5,
        op3: u6,
        reserved: u19 = 0b0000000000000000000,
    },

    //Format 4 (op = 2): MOVcc, FMOVr, FMOVcc, and Tcc
    format_4a: struct {
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
    format_4b: struct {
        op: u2 = 0b10,
        rd: u5,
        op3: u6,
        rs1: u5,
        i: u1 = 0b1,
        cc1: u1,
        cc0: u1,
        simm11: u11,
    },
    format_4c: struct {
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
    format_4d: struct {
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
    format_4e: struct {
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
    format_4f: struct {
        op: u2 = 0b10,
        rd: u5,
        op3: u6,
        rs1: u5,
        fixed: u1 = 0b0,
        rcond: u3,
        opf_low: u5,
        rs2: u5,
    },
    format_4g: struct {
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
        reserved2,
        ne_zero,
        gt_zero,
        ge_zero,

        /// Returns the condition which is true iff the given condition is
        /// false (if such a condition exists).
        pub fn negate(cond: RCondition) RCondition {
            return switch (cond) {
                .eq_zero => .ne_zero,
                .ne_zero => .eq_zero,
                .lt_zero => .ge_zero,
                .ge_zero => .lt_zero,
                .le_zero => .gt_zero,
                .gt_zero => .le_zero,
                .reserved1 => unreachable,
                .reserved2 => unreachable,
            };
        }
    };

    pub const ASI = enum(u8) {
        asi_nucleus = 0x04,
        asi_nucleus_little = 0x0c,
        asi_as_if_user_primary = 0x10,
        asi_as_if_user_secondary = 0x11,
        asi_as_if_user_primary_little = 0x18,
        asi_as_if_user_secondary_little = 0x19,
        asi_primary = 0x80,
        asi_secondary = 0x81,
        asi_primary_nofault = 0x82,
        asi_secondary_nofault = 0x83,
        asi_primary_little = 0x88,
        asi_secondary_little = 0x89,
        asi_primary_nofault_little = 0x8a,
        asi_secondary_nofault_little = 0x8b,
    };

    pub const ShiftWidth = enum(u1) {
        shift32,
        shift64,
    };

    pub const MemOrderingConstraint = packed struct {
        store_store: bool = false,
        load_store: bool = false,
        store_load: bool = false,
        load_load: bool = false,
    };

    pub const MemCompletionConstraint = packed struct {
        sync: bool = false,
        mem_issue: bool = false,
        lookaside: bool = false,
    };

    // In SPARCv9, FP and integer comparison operations
    // are encoded differently.

    pub const FCondition = enum(u4) {
        /// Branch Never
        nv,
        /// Branch on Not Equal
        ne,
        /// Branch on Less or Greater
        lg,
        /// Branch on Unordered or Less
        ul,
        /// Branch on Less
        lt,
        /// Branch on Unordered or Greater
        ug,
        /// Branch on Greater
        gt,
        /// Branch on Unordered
        un,
        /// Branch Always
        al,
        /// Branch on Equal
        eq,
        /// Branch on Unordered or Equal
        ue,
        /// Branch on Greater or Equal
        ge,
        /// Branch on Unordered or Greater or Equal
        uge,
        /// Branch on Less or Equal
        le,
        /// Branch on Unordered or Less or Equal
        ule,
        /// Branch on Ordered
        ord,

        /// Converts a std.math.CompareOperator into a condition flag,
        /// i.e. returns the condition that is true iff the result of the
        /// comparison is true.
        pub fn fromCompareOperator(op: std.math.CompareOperator) FCondition {
            return switch (op) {
                .gte => .ge,
                .gt => .gt,
                .neq => .ne,
                .lt => .lt,
                .lte => .le,
                .eq => .eq,
            };
        }

        /// Returns the condition which is true iff the given condition is
        /// false (if such a condition exists).
        pub fn negate(cond: FCondition) FCondition {
            return switch (cond) {
                .eq => .ne,
                .ne => .eq,
                .ge => .ul,
                .ul => .ge,
                .le => .ug,
                .ug => .le,
                .lt => .uge,
                .uge => .lt,
                .gt => .ule,
                .ule => .gt,
                .ue => .lg,
                .lg => .ue,
                .ord => .un,
                .un => .ord,
                .al => unreachable,
                .nv => unreachable,
            };
        }
    };

    pub const ICondition = enum(u4) {
        /// Branch Never
        nv,
        /// Branch on Equal
        eq,
        /// Branch on Less or Equal
        le,
        /// Branch on Less
        lt,
        /// Branch on Less or Equal Unsigned
        leu,
        /// Branch on Carry Set (Less than, Unsigned)
        cs,
        /// Branch on Negative
        neg,
        /// Branch on Overflow Set
        vs,
        /// Branch Always
        al,
        /// Branch on Not Equal
        ne,
        /// Branch on Greater
        gt,
        /// Branch on Greater or Equal
        ge,
        /// Branch on Greater Unsigned
        gu,
        /// Branch on Carry Clear (Greater Than or Equal, Unsigned)
        cc,
        /// Branch on Positive
        pos,
        /// Branch on Overflow Clear
        vc,

        /// Converts a std.math.CompareOperator into a condition flag,
        /// i.e. returns the condition that is true iff the result of the
        /// comparison is true. Assumes signed comparison.
        pub fn fromCompareOperatorSigned(op: std.math.CompareOperator) ICondition {
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
        /// comparison is true. Assumes unsigned comparison.
        pub fn fromCompareOperatorUnsigned(op: std.math.CompareOperator) ICondition {
            return switch (op) {
                .gte => .cc,
                .gt => .gu,
                .neq => .ne,
                .lt => .cs,
                .lte => .leu,
                .eq => .eq,
            };
        }

        /// Returns the condition which is true iff the given condition is
        /// false (if such a condition exists).
        pub fn negate(cond: ICondition) ICondition {
            return switch (cond) {
                .eq => .ne,
                .ne => .eq,
                .cs => .cc,
                .cc => .cs,
                .neg => .pos,
                .pos => .neg,
                .vs => .vc,
                .vc => .vs,
                .gu => .leu,
                .leu => .gu,
                .ge => .lt,
                .lt => .ge,
                .gt => .le,
                .le => .gt,
                .al => unreachable,
                .nv => unreachable,
            };
        }
    };

    pub const ConditionTag = enum { fcond, icond };
    pub const Condition = union(ConditionTag) {
        fcond: FCondition,
        icond: ICondition,

        /// Encodes the condition into the instruction bit pattern.
        pub fn enc(cond: Condition) u4 {
            return switch (cond) {
                .icond => |c| @intFromEnum(c),
                .fcond => |c| @intFromEnum(c),
            };
        }

        /// Returns the condition which is true iff the given condition is
        /// false (if such a condition exists).
        pub fn negate(cond: Condition) Condition {
            return switch (cond) {
                .icond => |c| .{ .icond = c.negate() },
                .fcond => |c| .{ .fcond = c.negate() },
            };
        }
    };

    pub fn toU32(self: Instruction) u32 {
        // TODO: Remove this once packed structs work.
        return switch (self) {
            .format_1 => |v| (@as(u32, v.op) << 30) | @as(u32, v.disp30),
            .format_2a => |v| (@as(u32, v.op) << 30) | (@as(u32, v.rd) << 25) | (@as(u32, v.op2) << 22) | @as(u32, v.imm22),
            .format_2b => |v| (@as(u32, v.op) << 30) | (@as(u32, v.a) << 29) | (@as(u32, v.cond) << 25) | (@as(u32, v.op2) << 22) | @as(u32, v.disp22),
            .format_2c => |v| (@as(u32, v.op) << 30) | (@as(u32, v.a) << 29) | (@as(u32, v.cond) << 25) | (@as(u32, v.op2) << 22) | (@as(u32, v.cc1) << 21) | (@as(u32, v.cc0) << 20) | (@as(u32, v.p) << 19) | @as(u32, v.disp19),
            .format_2d => |v| (@as(u32, v.op) << 30) | (@as(u32, v.a) << 29) | (@as(u32, v.fixed) << 28) | (@as(u32, v.rcond) << 25) | (@as(u32, v.op2) << 22) | (@as(u32, v.d16hi) << 20) | (@as(u32, v.p) << 19) | (@as(u32, v.rs1) << 14) | @as(u32, v.d16lo),
            .format_3a => |v| (@as(u32, v.op) << 30) | (@as(u32, v.rd) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.rs1) << 14) | (@as(u32, v.i) << 13) | (@as(u32, v.reserved) << 5) | @as(u32, v.rs2),
            .format_3b => |v| (@as(u32, v.op) << 30) | (@as(u32, v.rd) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.rs1) << 14) | (@as(u32, v.i) << 13) | @as(u32, v.simm13),
            .format_3c => |v| (@as(u32, v.op) << 30) | (@as(u32, v.reserved1) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.rs1) << 14) | (@as(u32, v.i) << 13) | (@as(u32, v.reserved2) << 5) | @as(u32, v.rs2),
            .format_3d => |v| (@as(u32, v.op) << 30) | (@as(u32, v.reserved) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.rs1) << 14) | (@as(u32, v.i) << 13) | @as(u32, v.simm13),
            .format_3e => |v| (@as(u32, v.op) << 30) | (@as(u32, v.rd) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.rs1) << 14) | (@as(u32, v.i) << 13) | (@as(u32, v.rcond) << 10) | (@as(u32, v.reserved) << 5) | @as(u32, v.rs2),
            .format_3f => |v| (@as(u32, v.op) << 30) | (@as(u32, v.rd) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.rs1) << 14) | (@as(u32, v.i) << 13) | (@as(u32, v.rcond) << 10) | @as(u32, v.simm10),
            .format_3g => |v| (@as(u32, v.op) << 30) | (@as(u32, v.rd) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.rs1) << 14) | (@as(u32, v.i) << 13) | (@as(u32, v.reserved) << 5) | @as(u32, v.rs2),
            .format_3h => |v| (@as(u32, v.op) << 30) | (@as(u32, v.fixed1) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.fixed2) << 14) | (@as(u32, v.i) << 13) | (@as(u32, v.reserved) << 7) | (@as(u32, v.cmask) << 4) | @as(u32, v.mmask),
            .format_3i => |v| (@as(u32, v.op) << 30) | (@as(u32, v.rd) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.rs1) << 14) | (@as(u32, v.i) << 13) | (@as(u32, v.imm_asi) << 5) | @as(u32, v.rs2),
            .format_3j => |v| (@as(u32, v.op) << 30) | (@as(u32, v.impl_dep1) << 25) | (@as(u32, v.op3) << 19) | @as(u32, v.impl_dep2),
            .format_3k => |v| (@as(u32, v.op) << 30) | (@as(u32, v.rd) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.rs1) << 14) | (@as(u32, v.i) << 13) | (@as(u32, v.x) << 12) | (@as(u32, v.reserved) << 5) | @as(u32, v.rs2),
            .format_3l => |v| (@as(u32, v.op) << 30) | (@as(u32, v.rd) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.rs1) << 14) | (@as(u32, v.i) << 13) | (@as(u32, v.x) << 12) | (@as(u32, v.reserved) << 5) | @as(u32, v.shcnt32),
            .format_3m => |v| (@as(u32, v.op) << 30) | (@as(u32, v.rd) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.rs1) << 14) | (@as(u32, v.i) << 13) | (@as(u32, v.x) << 12) | (@as(u32, v.reserved) << 6) | @as(u32, v.shcnt64),
            .format_3n => |v| (@as(u32, v.op) << 30) | (@as(u32, v.rd) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.reserved) << 14) | (@as(u32, v.opf) << 5) | @as(u32, v.rs2),
            .format_3o => |v| (@as(u32, v.op) << 30) | (@as(u32, v.fixed) << 27) | (@as(u32, v.cc1) << 26) | (@as(u32, v.cc0) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.rs1) << 14) | (@as(u32, v.opf) << 5) | @as(u32, v.rs2),
            .format_3p => |v| (@as(u32, v.op) << 30) | (@as(u32, v.rd) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.rs1) << 14) | (@as(u32, v.opf) << 5) | @as(u32, v.rs2),
            .format_3q => |v| (@as(u32, v.op) << 30) | (@as(u32, v.rd) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.rs1) << 14) | @as(u32, v.reserved),
            .format_3r => |v| (@as(u32, v.op) << 30) | (@as(u32, v.fcn) << 25) | (@as(u32, v.op3) << 19) | @as(u32, v.reserved),
            .format_3s => |v| (@as(u32, v.op) << 30) | (@as(u32, v.rd) << 25) | (@as(u32, v.op3) << 19) | @as(u32, v.reserved),
            .format_4a => |v| (@as(u32, v.op) << 30) | (@as(u32, v.rd) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.rs1) << 14) | (@as(u32, v.i) << 13) | (@as(u32, v.cc1) << 12) | (@as(u32, v.cc0) << 11) | (@as(u32, v.reserved) << 5) | @as(u32, v.rs2),
            .format_4b => |v| (@as(u32, v.op) << 30) | (@as(u32, v.rd) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.rs1) << 14) | (@as(u32, v.i) << 13) | (@as(u32, v.cc1) << 12) | (@as(u32, v.cc0) << 11) | @as(u32, v.simm11),
            .format_4c => |v| (@as(u32, v.op) << 30) | (@as(u32, v.rd) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.cc2) << 18) | (@as(u32, v.cond) << 14) | (@as(u32, v.i) << 13) | (@as(u32, v.cc1) << 12) | (@as(u32, v.cc0) << 11) | (@as(u32, v.reserved) << 5) | @as(u32, v.rs2),
            .format_4d => |v| (@as(u32, v.op) << 30) | (@as(u32, v.rd) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.cc2) << 18) | (@as(u32, v.cond) << 14) | (@as(u32, v.i) << 13) | (@as(u32, v.cc1) << 12) | (@as(u32, v.cc0) << 11) | @as(u32, v.simm11),
            .format_4e => |v| (@as(u32, v.op) << 30) | (@as(u32, v.rd) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.rs1) << 14) | (@as(u32, v.i) << 13) | (@as(u32, v.cc1) << 12) | (@as(u32, v.cc0) << 11) | (@as(u32, v.reserved) << 7) | @as(u32, v.sw_trap),
            .format_4f => |v| (@as(u32, v.op) << 30) | (@as(u32, v.rd) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.rs1) << 14) | (@as(u32, v.fixed) << 13) | (@as(u32, v.rcond) << 10) | (@as(u32, v.opf_low) << 5) | @as(u32, v.rs2),
            .format_4g => |v| (@as(u32, v.op) << 30) | (@as(u32, v.rd) << 25) | (@as(u32, v.op3) << 19) | (@as(u32, v.fixed) << 18) | (@as(u32, v.cond) << 14) | (@as(u32, v.opf_cc) << 11) | (@as(u32, v.opf_low) << 5) | @as(u32, v.rs2),
        };
    }

    // SPARCv9 Instruction formats.
    // See section 6.2 of the SPARCv9 ISA manual.

    fn format1(disp: i32) Instruction {
        const udisp = @as(u32, @bitCast(disp));

        // In SPARC, branch target needs to be aligned to 4 bytes.
        assert(udisp % 4 == 0);

        // Discard the last two bits since those are implicitly zero.
        const udisp_truncated = @as(u30, @truncate(udisp >> 2));
        return Instruction{
            .format_1 = .{
                .disp30 = udisp_truncated,
            },
        };
    }

    fn format2a(op2: u3, imm: u22, rd: Register) Instruction {
        return Instruction{
            .format_2a = .{
                .rd = rd.enc(),
                .op2 = op2,
                .imm22 = imm,
            },
        };
    }

    fn format2b(op2: u3, cond: Condition, annul: bool, disp: i24) Instruction {
        const udisp = @as(u24, @bitCast(disp));

        // In SPARC, branch target needs to be aligned to 4 bytes.
        assert(udisp % 4 == 0);

        // Discard the last two bits since those are implicitly zero.
        const udisp_truncated = @as(u22, @truncate(udisp >> 2));
        return Instruction{
            .format_2b = .{
                .a = @intFromBool(annul),
                .cond = cond.enc(),
                .op2 = op2,
                .disp22 = udisp_truncated,
            },
        };
    }

    fn format2c(op2: u3, cond: Condition, annul: bool, pt: bool, ccr: CCR, disp: i21) Instruction {
        const udisp = @as(u21, @bitCast(disp));

        // In SPARC, branch target needs to be aligned to 4 bytes.
        assert(udisp % 4 == 0);

        // Discard the last two bits since those are implicitly zero.
        const udisp_truncated = @as(u19, @truncate(udisp >> 2));

        const ccr_cc1 = @as(u1, @truncate(@intFromEnum(ccr) >> 1));
        const ccr_cc0 = @as(u1, @truncate(@intFromEnum(ccr)));
        return Instruction{
            .format_2c = .{
                .a = @intFromBool(annul),
                .cond = cond.enc(),
                .op2 = op2,
                .cc1 = ccr_cc1,
                .cc0 = ccr_cc0,
                .p = @intFromBool(pt),
                .disp19 = udisp_truncated,
            },
        };
    }

    fn format2d(op2: u3, rcond: RCondition, annul: bool, pt: bool, rs1: Register, disp: i18) Instruction {
        const udisp = @as(u18, @bitCast(disp));

        // In SPARC, branch target needs to be aligned to 4 bytes.
        assert(udisp % 4 == 0);

        // Discard the last two bits since those are implicitly zero,
        // and split it into low and high parts.
        const udisp_truncated = @as(u16, @truncate(udisp >> 2));
        const udisp_hi = @as(u2, @truncate((udisp_truncated & 0b1100_0000_0000_0000) >> 14));
        const udisp_lo = @as(u14, @truncate(udisp_truncated & 0b0011_1111_1111_1111));
        return Instruction{
            .format_2d = .{
                .a = @intFromBool(annul),
                .rcond = @intFromEnum(rcond),
                .op2 = op2,
                .p = @intFromBool(pt),
                .rs1 = rs1.enc(),
                .d16hi = udisp_hi,
                .d16lo = udisp_lo,
            },
        };
    }

    fn format3a(op: u2, op3: u6, rs1: Register, rs2: Register, rd: Register) Instruction {
        return Instruction{
            .format_3a = .{
                .op = op,
                .rd = rd.enc(),
                .op3 = op3,
                .rs1 = rs1.enc(),
                .rs2 = rs2.enc(),
            },
        };
    }
    fn format3b(op: u2, op3: u6, rs1: Register, imm: i13, rd: Register) Instruction {
        return Instruction{
            .format_3b = .{
                .op = op,
                .rd = rd.enc(),
                .op3 = op3,
                .rs1 = rs1.enc(),
                .simm13 = @as(u13, @bitCast(imm)),
            },
        };
    }
    fn format3c(op: u2, op3: u6, rs1: Register, rs2: Register) Instruction {
        return Instruction{
            .format_3c = .{
                .op = op,
                .op3 = op3,
                .rs1 = rs1.enc(),
                .rs2 = rs2.enc(),
            },
        };
    }
    fn format3d(op: u2, op3: u6, rs1: Register, imm: i13) Instruction {
        return Instruction{
            .format_3d = .{
                .op = op,
                .op3 = op3,
                .rs1 = rs1.enc(),
                .simm13 = @as(u13, @bitCast(imm)),
            },
        };
    }
    fn format3e(op: u2, op3: u6, rcond: RCondition, rs1: Register, rs2: Register, rd: Register) Instruction {
        return Instruction{
            .format_3e = .{
                .op = op,
                .rd = rd.enc(),
                .op3 = op3,
                .rs1 = rs1.enc(),
                .rcond = @intFromEnum(rcond),
                .rs2 = rs2.enc(),
            },
        };
    }
    fn format3f(op: u2, op3: u6, rcond: RCondition, rs1: Register, imm: i10, rd: Register) Instruction {
        return Instruction{
            .format_3f = .{
                .op = op,
                .rd = rd.enc(),
                .op3 = op3,
                .rs1 = rs1.enc(),
                .rcond = @intFromEnum(rcond),
                .simm10 = @as(u10, @bitCast(imm)),
            },
        };
    }
    fn format3g(op: u2, op3: u6, rs1: Register, rs2: Register, rd: Register) Instruction {
        return Instruction{
            .format_3g = .{
                .op = op,
                .rd = rd.enc(),
                .op3 = op3,
                .rs1 = rs1.enc(),
                .rs2 = rs2.enc(),
            },
        };
    }
    fn format3h(cmask: MemCompletionConstraint, mmask: MemOrderingConstraint) Instruction {
        return Instruction{
            .format_3h = .{
                .cmask = @as(u3, @bitCast(cmask)),
                .mmask = @as(u4, @bitCast(mmask)),
            },
        };
    }
    fn format3i(op: u2, op3: u6, rs1: Register, rs2: Register, rd: Register, asi: ASI) Instruction {
        return Instruction{
            .format_3i = .{
                .op = op,
                .rd = rd.enc(),
                .op3 = op3,
                .rs1 = rs1.enc(),
                .imm_asi = @intFromEnum(asi),
                .rs2 = rs2.enc(),
            },
        };
    }
    fn format3j(op: u2, op3: u6, impl_dep1: u5, impl_dep2: u19) Instruction {
        return Instruction{
            .format_3j = .{
                .op = op,
                .impl_dep1 = impl_dep1,
                .op3 = op3,
                .impl_dep2 = impl_dep2,
            },
        };
    }
    fn format3k(op: u2, op3: u6, sw: ShiftWidth, rs1: Register, rs2: Register, rd: Register) Instruction {
        return Instruction{
            .format_3k = .{
                .op = op,
                .rd = rd.enc(),
                .op3 = op3,
                .rs1 = rs1.enc(),
                .x = @intFromEnum(sw),
                .rs2 = rs2.enc(),
            },
        };
    }
    fn format3l(op: u2, op3: u6, rs1: Register, shift_count: u5, rd: Register) Instruction {
        return Instruction{
            .format_3l = .{
                .op = op,
                .rd = rd.enc(),
                .op3 = op3,
                .rs1 = rs1.enc(),
                .shcnt32 = shift_count,
            },
        };
    }
    fn format3m(op: u2, op3: u6, rs1: Register, shift_count: u6, rd: Register) Instruction {
        return Instruction{
            .format_3m = .{
                .op = op,
                .rd = rd.enc(),
                .op3 = op3,
                .rs1 = rs1.enc(),
                .shcnt64 = shift_count,
            },
        };
    }
    fn format3n(op: u2, op3: u6, opf: u9, rs2: Register, rd: Register) Instruction {
        return Instruction{
            .format_3n = .{
                .op = op,
                .rd = rd.enc(),
                .op3 = op3,
                .opf = opf,
                .rs2 = rs2.enc(),
            },
        };
    }
    fn format3o(op: u2, op3: u6, opf: u9, ccr: CCR, rs1: Register, rs2: Register) Instruction {
        const ccr_cc1 = @as(u1, @truncate(@intFromEnum(ccr) >> 1));
        const ccr_cc0 = @as(u1, @truncate(@intFromEnum(ccr)));
        return Instruction{
            .format_3o = .{
                .op = op,
                .cc1 = ccr_cc1,
                .cc0 = ccr_cc0,
                .op3 = op3,
                .rs1 = rs1.enc(),
                .opf = opf,
                .rs2 = rs2.enc(),
            },
        };
    }
    fn format3p(op: u2, op3: u6, opf: u9, rs1: Register, rs2: Register, rd: Register) Instruction {
        return Instruction{
            .format_3p = .{
                .op = op,
                .rd = rd.enc(),
                .op3 = op3,
                .rs1 = rs1.enc(),
                .opf = opf,
                .rs2 = rs2.enc(),
            },
        };
    }
    fn format3q(op: u2, op3: u6, rs1: Register, rd: Register) Instruction {
        return Instruction{
            .format_3q = .{
                .op = op,
                .rd = rd.enc(),
                .op3 = op3,
                .rs1 = rs1.enc(),
            },
        };
    }
    fn format3r(op: u2, op3: u6, fcn: u5) Instruction {
        return Instruction{
            .format_3r = .{
                .op = op,
                .fcn = fcn,
                .op3 = op3,
            },
        };
    }
    fn format3s(op: u2, op3: u6, rd: Register) Instruction {
        return Instruction{
            .format_3s = .{
                .op = op,
                .rd = rd.enc(),
                .op3 = op3,
            },
        };
    }

    fn format4a(op3: u6, ccr: CCR, rs1: Register, rs2: Register, rd: Register) Instruction {
        const ccr_cc1 = @as(u1, @truncate(@intFromEnum(ccr) >> 1));
        const ccr_cc0 = @as(u1, @truncate(@intFromEnum(ccr)));
        return Instruction{
            .format_4a = .{
                .rd = rd.enc(),
                .op3 = op3,
                .rs1 = rs1.enc(),
                .cc1 = ccr_cc1,
                .cc0 = ccr_cc0,
                .rs2 = rs2.enc(),
            },
        };
    }

    fn format4b(op3: u6, ccr: CCR, rs1: Register, imm: i11, rd: Register) Instruction {
        const ccr_cc1 = @as(u1, @truncate(@intFromEnum(ccr) >> 1));
        const ccr_cc0 = @as(u1, @truncate(@intFromEnum(ccr)));
        return Instruction{
            .format_4b = .{
                .rd = rd.enc(),
                .op3 = op3,
                .rs1 = rs1.enc(),
                .cc1 = ccr_cc1,
                .cc0 = ccr_cc0,
                .simm11 = @as(u11, @bitCast(imm)),
            },
        };
    }

    fn format4c(op3: u6, cond: Condition, ccr: CCR, rs2: Register, rd: Register) Instruction {
        const ccr_cc2 = @as(u1, @truncate(@intFromEnum(ccr) >> 2));
        const ccr_cc1 = @as(u1, @truncate(@intFromEnum(ccr) >> 1));
        const ccr_cc0 = @as(u1, @truncate(@intFromEnum(ccr)));
        return Instruction{
            .format_4c = .{
                .rd = rd.enc(),
                .op3 = op3,
                .cc2 = ccr_cc2,
                .cond = cond.enc(),
                .cc1 = ccr_cc1,
                .cc0 = ccr_cc0,
                .rs2 = rs2.enc(),
            },
        };
    }

    fn format4d(op3: u6, cond: Condition, ccr: CCR, imm: i11, rd: Register) Instruction {
        const ccr_cc2 = @as(u1, @truncate(@intFromEnum(ccr) >> 2));
        const ccr_cc1 = @as(u1, @truncate(@intFromEnum(ccr) >> 1));
        const ccr_cc0 = @as(u1, @truncate(@intFromEnum(ccr)));
        return Instruction{
            .format_4d = .{
                .rd = rd.enc(),
                .op3 = op3,
                .cc2 = ccr_cc2,
                .cond = cond.enc(),
                .cc1 = ccr_cc1,
                .cc0 = ccr_cc0,
                .simm11 = @as(u11, @bitCast(imm)),
            },
        };
    }

    fn format4e(op3: u6, ccr: CCR, rs1: Register, rd: Register, sw_trap: u7) Instruction {
        const ccr_cc1 = @as(u1, @truncate(@intFromEnum(ccr) >> 1));
        const ccr_cc0 = @as(u1, @truncate(@intFromEnum(ccr)));
        return Instruction{
            .format_4e = .{
                .rd = rd.enc(),
                .op3 = op3,
                .rs1 = rs1.enc(),
                .cc1 = ccr_cc1,
                .cc0 = ccr_cc0,
                .sw_trap = sw_trap,
            },
        };
    }

    fn format4f(
        op3: u6,
        opf_low: u5,
        rcond: RCondition,
        rs1: Register,
        rs2: Register,
        rd: Register,
    ) Instruction {
        return Instruction{
            .format_4f = .{
                .rd = rd.enc(),
                .op3 = op3,
                .rs1 = rs1.enc(),
                .rcond = @intFromEnum(rcond),
                .opf_low = opf_low,
                .rs2 = rs2.enc(),
            },
        };
    }

    fn format4g(op3: u6, opf_low: u6, opf_cc: u3, cond: Condition, rs2: Register, rd: Register) Instruction {
        return Instruction{
            .format_4g = .{
                .rd = rd.enc(),
                .op3 = op3,
                .cond = cond.enc(),
                .opf_cc = opf_cc,
                .opf_low = opf_low,
                .rs2 = rs2.enc(),
            },
        };
    }

    // SPARCv9 Instruction definition.
    // See appendix A of the SPARCv9 ISA manual.

    pub fn add(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b10, 0b00_0000, rs1, rs2, rd),
            i13 => format3b(0b10, 0b00_0000, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn addcc(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b10, 0b01_0000, rs1, rs2, rd),
            i13 => format3b(0b10, 0b01_0000, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn bpcc(cond: ICondition, annul: bool, pt: bool, ccr: CCR, disp: i21) Instruction {
        return format2c(0b001, .{ .icond = cond }, annul, pt, ccr, disp);
    }

    pub fn bpr(cond: RCondition, annul: bool, pt: bool, rs1: Register, disp: i18) Instruction {
        return format2d(0b011, cond, annul, pt, rs1, disp);
    }

    pub fn jmpl(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b10, 0b11_1000, rs1, rs2, rd),
            i13 => format3b(0b10, 0b11_1000, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn ldub(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b11, 0b00_0001, rs1, rs2, rd),
            i13 => format3b(0b11, 0b00_0001, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn lduh(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b11, 0b00_0010, rs1, rs2, rd),
            i13 => format3b(0b11, 0b00_0010, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn lduw(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b11, 0b00_0000, rs1, rs2, rd),
            i13 => format3b(0b11, 0b00_0000, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn ldx(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b11, 0b00_1011, rs1, rs2, rd),
            i13 => format3b(0b11, 0b00_1011, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn lduba(rs1: Register, rs2: Register, asi: ASI, rd: Register) Instruction {
        return format3i(0b11, 0b01_0001, rs1, rs2, rd, asi);
    }

    pub fn lduha(rs1: Register, rs2: Register, asi: ASI, rd: Register) Instruction {
        return format3i(0b11, 0b01_0010, rs1, rs2, rd, asi);
    }

    pub fn lduwa(rs1: Register, rs2: Register, asi: ASI, rd: Register) Instruction {
        return format3i(0b11, 0b01_0000, rs1, rs2, rd, asi);
    }

    pub fn ldxa(rs1: Register, rs2: Register, asi: ASI, rd: Register) Instruction {
        return format3i(0b11, 0b01_1011, rs1, rs2, rd, asi);
    }

    pub fn @"and"(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b10, 0b00_0001, rs1, rs2, rd),
            i13 => format3b(0b10, 0b00_0001, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn @"or"(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b10, 0b00_0010, rs1, rs2, rd),
            i13 => format3b(0b10, 0b00_0010, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn xor(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b10, 0b00_0011, rs1, rs2, rd),
            i13 => format3b(0b10, 0b00_0011, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn xnor(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b10, 0b00_0111, rs1, rs2, rd),
            i13 => format3b(0b10, 0b00_0111, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn membar(cmask: MemCompletionConstraint, mmask: MemOrderingConstraint) Instruction {
        return format3h(cmask, mmask);
    }

    pub fn movcc(comptime s2: type, cond: Condition, ccr: CCR, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format4c(0b10_1100, cond, ccr, rs2, rd),
            i11 => format4d(0b10_1100, cond, ccr, rs2, rd),
            else => unreachable,
        };
    }

    pub fn movr(comptime s2: type, cond: RCondition, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3e(0b10, 0b10_1111, cond, rs1, rs2, rd),
            i10 => format3f(0b10, 0b10_1111, cond, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn mulx(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b10, 0b00_1001, rs1, rs2, rd),
            i13 => format3b(0b10, 0b00_1001, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn sdivx(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b10, 0b10_1101, rs1, rs2, rd),
            i13 => format3b(0b10, 0b10_1101, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn udivx(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b10, 0b00_1101, rs1, rs2, rd),
            i13 => format3b(0b10, 0b00_1101, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn nop() Instruction {
        return sethi(0, .g0);
    }

    pub fn @"return"(comptime s2: type, rs1: Register, rs2: s2) Instruction {
        return switch (s2) {
            Register => format3c(0b10, 0b11_1001, rs1, rs2),
            i13 => format3d(0b10, 0b11_1001, rs1, rs2),
            else => unreachable,
        };
    }

    pub fn save(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b10, 0b11_1100, rs1, rs2, rd),
            i13 => format3b(0b10, 0b11_1100, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn restore(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b10, 0b11_1101, rs1, rs2, rd),
            i13 => format3b(0b10, 0b11_1101, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn sethi(imm: u22, rd: Register) Instruction {
        return format2a(0b100, imm, rd);
    }

    pub fn sll(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3k(0b10, 0b10_0101, .shift32, rs1, rs2, rd),
            u5 => format3l(0b10, 0b10_0101, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn srl(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3k(0b10, 0b10_0110, .shift32, rs1, rs2, rd),
            u5 => format3l(0b10, 0b10_0110, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn sra(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3k(0b10, 0b10_0111, .shift32, rs1, rs2, rd),
            u5 => format3l(0b10, 0b10_0111, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn sllx(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3k(0b10, 0b10_0101, .shift64, rs1, rs2, rd),
            u6 => format3m(0b10, 0b10_0101, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn srlx(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3k(0b10, 0b10_0110, .shift64, rs1, rs2, rd),
            u6 => format3m(0b10, 0b10_0110, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn srax(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3k(0b10, 0b10_0111, .shift64, rs1, rs2, rd),
            u6 => format3m(0b10, 0b10_0111, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn stb(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b11, 0b00_0101, rs1, rs2, rd),
            i13 => format3b(0b11, 0b00_0101, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn sth(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b11, 0b00_0110, rs1, rs2, rd),
            i13 => format3b(0b11, 0b00_0110, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn stw(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b11, 0b00_0100, rs1, rs2, rd),
            i13 => format3b(0b11, 0b00_0100, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn stx(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b11, 0b00_1110, rs1, rs2, rd),
            i13 => format3b(0b11, 0b00_1110, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn stba(rs1: Register, rs2: Register, asi: ASI, rd: Register) Instruction {
        return format3i(0b11, 0b01_0101, rs1, rs2, rd, asi);
    }

    pub fn stha(rs1: Register, rs2: Register, asi: ASI, rd: Register) Instruction {
        return format3i(0b11, 0b01_0110, rs1, rs2, rd, asi);
    }

    pub fn stwa(rs1: Register, rs2: Register, asi: ASI, rd: Register) Instruction {
        return format3i(0b11, 0b01_0100, rs1, rs2, rd, asi);
    }

    pub fn stxa(rs1: Register, rs2: Register, asi: ASI, rd: Register) Instruction {
        return format3i(0b11, 0b01_1110, rs1, rs2, rd, asi);
    }

    pub fn sub(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b10, 0b00_0100, rs1, rs2, rd),
            i13 => format3b(0b10, 0b00_0100, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn subcc(comptime s2: type, rs1: Register, rs2: s2, rd: Register) Instruction {
        return switch (s2) {
            Register => format3a(0b10, 0b01_0100, rs1, rs2, rd),
            i13 => format3b(0b10, 0b01_0100, rs1, rs2, rd),
            else => unreachable,
        };
    }

    pub fn trap(comptime s2: type, cond: ICondition, ccr: CCR, rs1: Register, rs2: s2) Instruction {
        // Tcc instructions abuse the rd field to store the conditionals.
        return switch (s2) {
            Register => format4a(0b11_1010, ccr, rs1, rs2, @as(Register, @enumFromInt(@intFromEnum(cond)))),
            u7 => format4e(0b11_1010, ccr, rs1, @as(Register, @enumFromInt(@intFromEnum(cond))), rs2),
            else => unreachable,
        };
    }
};

test "Serialize formats" {
    const Testcase = struct {
        inst: Instruction,
        expected: u32,
    };

    // Note that the testcases might or might not be a valid instruction
    // This is mostly just to check the behavior of the format packed structs
    // since currently stage1 doesn't properly implement it in all cases
    const testcases = [_]Testcase{
        .{
            .inst = Instruction.format1(4),
            .expected = 0b01_000000000000000000000000000001,
        },
        .{
            .inst = Instruction.format2a(4, 0, .g0),
            .expected = 0b00_00000_100_0000000000000000000000,
        },
        .{
            .inst = Instruction.format2b(6, .{ .icond = .lt }, true, -4),
            .expected = 0b00_1_0011_110_1111111111111111111111,
        },
        .{
            .inst = Instruction.format2c(3, .{ .icond = .nv }, false, true, .xcc, 8),
            .expected = 0b00_0_0000_011_1_0_1_0000000000000000010,
        },
        .{
            .inst = Instruction.format2d(7, .eq_zero, false, true, .o0, 20),
            .expected = 0b00_0_0_001_111_00_1_01000_00000000000101,
        },
        .{
            .inst = Instruction.format3a(3, 5, .g0, .o1, .l2),
            .expected = 0b11_10010_000101_00000_0_00000000_01001,
        },
        .{
            .inst = Instruction.format3b(3, 5, .g0, -1, .l2),
            .expected = 0b11_10010_000101_00000_1_1111111111111,
        },
        .{
            .inst = Instruction.format3c(3, 5, .g0, .o1),
            .expected = 0b11_00000_000101_00000_0_00000000_01001,
        },
        .{
            .inst = Instruction.format3d(3, 5, .g0, 0),
            .expected = 0b11_00000_000101_00000_1_0000000000000,
        },
        .{
            .inst = Instruction.format3e(3, 5, .ne_zero, .g0, .o1, .l2),
            .expected = 0b11_10010_000101_00000_0_101_00000_01001,
        },
        .{
            .inst = Instruction.format3f(3, 5, .ne_zero, .g0, -1, .l2),
            .expected = 0b11_10010_000101_00000_1_101_1111111111,
        },
        .{
            .inst = Instruction.format3g(3, 5, .g0, .o1, .l2),
            .expected = 0b11_10010_000101_00000_1_00000000_01001,
        },
        .{
            .inst = Instruction.format3h(.{}, .{}),
            .expected = 0b10_00000_101000_01111_1_000000_000_0000,
        },
        .{
            .inst = Instruction.format3i(3, 5, .g0, .o1, .l2, .asi_primary_little),
            .expected = 0b11_10010_000101_00000_0_10001000_01001,
        },
        .{
            .inst = Instruction.format3j(3, 5, 31, 0),
            .expected = 0b11_11111_000101_0000000000000000000,
        },
        .{
            .inst = Instruction.format3k(3, 5, .shift32, .g0, .o1, .l2),
            .expected = 0b11_10010_000101_00000_0_0_0000000_01001,
        },
        .{
            .inst = Instruction.format3l(3, 5, .g0, 31, .l2),
            .expected = 0b11_10010_000101_00000_1_0_0000000_11111,
        },
        .{
            .inst = Instruction.format3m(3, 5, .g0, 63, .l2),
            .expected = 0b11_10010_000101_00000_1_1_000000_111111,
        },
        .{
            .inst = Instruction.format3n(3, 5, 0, .o1, .l2),
            .expected = 0b11_10010_000101_00000_000000000_01001,
        },
        .{
            .inst = Instruction.format3o(3, 5, 0, .xcc, .o1, .l2),
            .expected = 0b11_000_1_0_000101_01001_000000000_10010,
        },
        .{
            .inst = Instruction.format3p(3, 5, 0, .g0, .o1, .l2),
            .expected = 0b11_10010_000101_00000_000000000_01001,
        },
        .{
            .inst = Instruction.format3q(3, 5, .g0, .o1),
            .expected = 0b11_01001_000101_00000_00000000000000,
        },
        .{
            .inst = Instruction.format3r(3, 5, 4),
            .expected = 0b11_00100_000101_0000000000000000000,
        },
        .{
            .inst = Instruction.format3s(3, 5, .g0),
            .expected = 0b11_00000_000101_0000000000000000000,
        },
        .{
            .inst = Instruction.format4a(8, .xcc, .g0, .o1, .l2),
            .expected = 0b10_10010_001000_00000_0_1_0_000000_01001,
        },
        .{
            .inst = Instruction.format4b(8, .xcc, .g0, -1, .l2),
            .expected = 0b10_10010_001000_00000_1_1_0_11111111111,
        },
        .{
            .inst = Instruction.format4c(8, .{ .icond = .nv }, .xcc, .g0, .o1),
            .expected = 0b10_01001_001000_1_0000_0_1_0_000000_00000,
        },
        .{
            .inst = Instruction.format4d(8, .{ .icond = .nv }, .xcc, 0, .l2),
            .expected = 0b10_10010_001000_1_0000_1_1_0_00000000000,
        },
        .{
            .inst = Instruction.format4e(8, .xcc, .g0, .o1, 0),
            .expected = 0b10_01001_001000_00000_1_1_0_0000_0000000,
        },
        .{
            .inst = Instruction.format4f(8, 4, .eq_zero, .g0, .o1, .l2),
            .expected = 0b10_10010_001000_00000_0_001_00100_01001,
        },
        .{
            .inst = Instruction.format4g(8, 4, 2, .{ .icond = .nv }, .o1, .l2),
            .expected = 0b10_10010_001000_0_0000_010_000100_01001,
        },
    };

    for (testcases) |case| {
        const actual = case.inst.toU32();
        testing.expectEqual(case.expected, actual) catch |err| {
            std.debug.print("error: {}\n", .{err});
            std.debug.print("case: {}\n", .{case});
            return err;
        };
    }
}
