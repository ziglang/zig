const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Mir = @import("Mir.zig");

/// EFLAGS condition codes
pub const Condition = enum(u5) {
    /// above
    a,
    /// above or equal
    ae,
    /// below
    b,
    /// below or equal
    be,
    /// carry
    c,
    /// equal
    e,
    /// greater
    g,
    /// greater or equal
    ge,
    /// less
    l,
    /// less or equal
    le,
    /// not above
    na,
    /// not above or equal
    nae,
    /// not below
    nb,
    /// not below or equal
    nbe,
    /// not carry
    nc,
    /// not equal
    ne,
    /// not greater
    ng,
    /// not greater or equal
    nge,
    /// not less
    nl,
    /// not less or equal
    nle,
    /// not overflow
    no,
    /// not parity
    np,
    /// not sign
    ns,
    /// not zero
    nz,
    /// overflow
    o,
    /// parity
    p,
    /// parity even
    pe,
    /// parity odd
    po,
    /// sign
    s,
    /// zero
    z,

    // Pseudo conditions
    /// zero and not parity
    z_and_np,
    /// not zero or parity
    nz_or_p,

    /// Converts a std.math.CompareOperator into a condition flag,
    /// i.e. returns the condition that is true iff the result of the
    /// comparison is true. Assumes signed comparison
    pub fn fromCompareOperatorSigned(op: std.math.CompareOperator) Condition {
        return switch (op) {
            .gte => .ge,
            .gt => .g,
            .neq => .ne,
            .lt => .l,
            .lte => .le,
            .eq => .e,
        };
    }

    /// Converts a std.math.CompareOperator into a condition flag,
    /// i.e. returns the condition that is true iff the result of the
    /// comparison is true. Assumes unsigned comparison
    pub fn fromCompareOperatorUnsigned(op: std.math.CompareOperator) Condition {
        return switch (op) {
            .gte => .ae,
            .gt => .a,
            .neq => .ne,
            .lt => .b,
            .lte => .be,
            .eq => .e,
        };
    }

    pub fn fromCompareOperator(
        signedness: std.builtin.Signedness,
        op: std.math.CompareOperator,
    ) Condition {
        return switch (signedness) {
            .signed => fromCompareOperatorSigned(op),
            .unsigned => fromCompareOperatorUnsigned(op),
        };
    }

    /// Returns the condition which is true iff the given condition is false
    pub fn negate(cond: Condition) Condition {
        return switch (cond) {
            .a => .na,
            .ae => .nae,
            .b => .nb,
            .be => .nbe,
            .c => .nc,
            .e => .ne,
            .g => .ng,
            .ge => .nge,
            .l => .nl,
            .le => .nle,
            .na => .a,
            .nae => .ae,
            .nb => .b,
            .nbe => .be,
            .nc => .c,
            .ne => .e,
            .ng => .g,
            .nge => .ge,
            .nl => .l,
            .nle => .le,
            .no => .o,
            .np => .p,
            .ns => .s,
            .nz => .z,
            .o => .no,
            .p => .np,
            .pe => .po,
            .po => .pe,
            .s => .ns,
            .z => .nz,

            .z_and_np => .nz_or_p,
            .nz_or_p => .z_and_np,
        };
    }

    /// Returns the equivalent condition when the operands are swapped.
    pub fn commute(cond: Condition) Condition {
        return switch (cond) {
            else => cond,
            .a => .b,
            .ae => .be,
            .b => .a,
            .be => .ae,
            .g => .l,
            .ge => .le,
            .l => .g,
            .le => .ge,
            .na => .nb,
            .nae => .nbe,
            .nb => .na,
            .nbe => .nae,
            .ng => .nl,
            .nge => .nle,
            .nl => .ng,
            .nle => .nge,
        };
    }
};

/// The immediate operand of vcvtps2ph.
pub const RoundMode = packed struct(u5) {
    direction: Direction = .mxcsr,
    precision: enum(u1) {
        normal = 0b0,
        inexact = 0b1,
    } = .normal,

    pub const Direction = enum(u4) {
        /// Round to nearest (even)
        nearest = 0b0_00,
        /// Round down (toward -∞)
        down = 0b0_01,
        /// Round up (toward +∞)
        up = 0b0_10,
        /// Round toward zero (truncate)
        zero = 0b0_11,
        /// Use current rounding mode of MXCSR.RC
        mxcsr = 0b1_00,
    };

    pub fn imm(mode: RoundMode) Immediate {
        return .u(@as(@typeInfo(RoundMode).@"struct".backing_integer.?, @bitCast(mode)));
    }
};

/// The immediate operand of cmppd, cmpps, cmpsd, and cmpss.
pub const SseFloatPredicate = enum(u3) {
    /// Equal (ordered, non-signaling)
    eq,
    /// Less-than (ordered, signaling)
    lt,
    /// Less-than-or-equal (ordered, signaling)
    le,
    /// Unordered (non-signaling)
    unord,
    /// Not-equal (unordered, non-signaling)
    neq,
    /// Not-less-than (unordered, signaling)
    nlt,
    /// Not-less-than-or-equal (unordered, signaling)
    nle,
    /// Ordered (non-signaling)
    ord,

    /// Equal (ordered, non-signaling)
    pub const eq_oq: SseFloatPredicate = .eq;
    /// Less-than (ordered, signaling)
    pub const lt_os: SseFloatPredicate = .lt;
    /// Less-than-or-equal (ordered, signaling)
    pub const le_os: SseFloatPredicate = .le;
    /// Unordered (non-signaling)
    pub const unord_q: SseFloatPredicate = .unord;
    /// Not-equal (unordered, non-signaling)
    pub const neq_uq: SseFloatPredicate = .neq;
    /// Not-less-than (unordered, signaling)
    pub const nlt_us: SseFloatPredicate = .nlt;
    /// Not-less-than-or-equal (unordered, signaling)
    pub const nle_us: SseFloatPredicate = .nle;
    /// Ordered (non-signaling)
    pub const ord_q: SseFloatPredicate = .ord;

    pub fn imm(pred: SseFloatPredicate) Immediate {
        return .u(@intFromEnum(pred));
    }
};

/// The immediate operand of vcmppd, vcmpps, vcmpsd, and vcmpss.
pub const VexFloatPredicate = enum(u5) {
    /// Equal (ordered, non-signaling)
    eq_oq,
    /// Less-than (ordered, signaling)
    lt_os,
    /// Less-than-or-equal (ordered, signaling)
    le_os,
    /// Unordered (non-signaling)
    unord_q,
    /// Not-equal (unordered, non-signaling)
    neq_uq,
    /// Not-less-than (unordered, signaling)
    nlt_us,
    /// Not-less-than-or-equal (unordered, signaling)
    nle_us,
    /// Ordered (non-signaling)
    ord_q,
    /// Equal (unordered, non-signaling)
    eq_uq,
    /// Not-greater-than-or-equal (unordered, signaling)
    nge_us,
    /// Not-greater-than (unordered, signaling)
    ngt_us,
    /// False (ordered, non-signaling)
    false_oq,
    /// Not-equal (ordered, non-signaling)
    neq_oq,
    /// Greater-than-or-equal (ordered, signaling)
    ge_os,
    /// Greater-than (ordered, signaling)
    gt_os,
    /// True (unordered, non-signaling)
    true_uq,
    /// Equal (unordered, non-signaling)
    eq_os,
    /// Less-than (ordered, non-signaling)
    lt_oq,
    /// Less-than-or-equal (ordered, non-signaling)
    le_oq,
    /// Unordered (signaling)
    unord_s,
    /// Not-equal (unordered, signaling)
    neq_us,
    /// Not-less-than (unordered, non-signaling)
    nlt_uq,
    /// Not-less-than-or-equal (unordered, non-signaling)
    nle_uq,
    /// Ordered (signaling)
    ord_s,
    /// Equal (unordered, signaling)
    eq_us,
    /// Not-greater-than-or-equal (unordered, non-signaling)
    nge_uq,
    /// Not-greater-than (unordered, non-signaling)
    ngt_uq,
    /// False (ordered, signaling)
    false_os,
    /// Not-equal (ordered, signaling)
    neq_os,
    /// Greater-than-or-equal (ordered, non-signaling)
    ge_oq,
    /// Greater-than (ordered, non-signaling)
    gt_oq,
    /// True (unordered, signaling)
    true_us,

    /// Equal (ordered, non-signaling)
    pub const eq: VexFloatPredicate = .eq_oq;
    /// Less-than (ordered, signaling)
    pub const lt: VexFloatPredicate = .lt_os;
    /// Less-than-or-equal (ordered, signaling)
    pub const le: VexFloatPredicate = .le_os;
    /// Unordered (non-signaling)
    pub const unord: VexFloatPredicate = .unord_q;
    /// Not-equal (unordered, non-signaling)
    pub const neq: VexFloatPredicate = .neq_uq;
    /// Not-less-than (unordered, signaling)
    pub const nlt: VexFloatPredicate = .nlt_us;
    /// Not-less-than-or-equal (unordered, signaling)
    pub const nle: VexFloatPredicate = .nle_us;
    /// Ordered (non-signaling)
    pub const ord: VexFloatPredicate = .ord_q;
    /// Not-greater-than-or-equal (unordered, signaling)
    pub const nge: VexFloatPredicate = .nge_us;
    /// Not-greater-than (unordered, signaling)
    pub const ngt: VexFloatPredicate = .ngt_us;
    /// False (ordered, non-signaling)
    pub const @"false": VexFloatPredicate = .false_oq;
    /// Greater-than-or-equal (ordered, signaling)
    pub const ge: VexFloatPredicate = .ge_os;
    /// Greater-than (ordered, signaling)
    pub const gt: VexFloatPredicate = .gt_os;
    /// True (unordered, non-signaling)
    pub const @"true": VexFloatPredicate = .true_uq;

    pub fn imm(pred: VexFloatPredicate) Immediate {
        return .u(@intFromEnum(pred));
    }
};

pub const Register = enum(u8) {
    // zig fmt: off
    rax, rcx, rdx, rbx, rsp, rbp, rsi, rdi,
    r8, r9, r10, r11, r12, r13, r14, r15,

    eax, ecx, edx, ebx, esp, ebp, esi, edi,
    r8d, r9d, r10d, r11d, r12d, r13d, r14d, r15d,

    ax, cx, dx, bx, sp, bp, si, di,
    r8w, r9w, r10w, r11w, r12w, r13w, r14w, r15w,

    al, cl, dl, bl, spl, bpl, sil, dil,
    r8b, r9b, r10b, r11b, r12b, r13b, r14b, r15b,

    ah, ch, dh, bh,

    zmm0,  zmm1, zmm2,  zmm3,  zmm4,  zmm5,  zmm6,  zmm7,
    zmm8,  zmm9, zmm10, zmm11, zmm12, zmm13, zmm14, zmm15,
    zmm16, zmm17,zmm18, zmm19, zmm20, zmm21, zmm22, zmm23,
    zmm24, zmm25,zmm26, zmm27, zmm28, zmm29, zmm30, zmm31,

    ymm0,  ymm1, ymm2,  ymm3,  ymm4,  ymm5,  ymm6,  ymm7,
    ymm8,  ymm9, ymm10, ymm11, ymm12, ymm13, ymm14, ymm15,
    ymm16, ymm17,ymm18, ymm19, ymm20, ymm21, ymm22, ymm23,
    ymm24, ymm25,ymm26, ymm27, ymm28, ymm29, ymm30, ymm31,

    xmm0,  xmm1, xmm2,  xmm3,  xmm4,  xmm5,  xmm6,  xmm7,
    xmm8,  xmm9, xmm10, xmm11, xmm12, xmm13, xmm14, xmm15,
    xmm16, xmm17,xmm18, xmm19, xmm20, xmm21, xmm22, xmm23,
    xmm24, xmm25,xmm26, xmm27, xmm28, xmm29, xmm30, xmm31,

    mm0, mm1, mm2, mm3, mm4, mm5, mm6, mm7,

    st0, st1, st2, st3, st4, st5, st6, st7,

    es, cs, ss, ds, fs, gs,

    rip, eip, ip,

    cr0, cr1, cr2,  cr3,  cr4,  cr5,  cr6,  cr7,
    cr8, cr9, cr10, cr11, cr12, cr13, cr14, cr15,

    dr0, dr1, dr2,  dr3,  dr4,  dr5,  dr6,  dr7,
    dr8, dr9, dr10, dr11, dr12, dr13, dr14, dr15,

    none,
    // zig fmt: on

    pub const Class = enum {
        general_purpose,
        gphi,
        segment,
        x87,
        mmx,
        sse,
        ip,
        cr,
        dr,
    };

    pub fn class(reg: Register) Class {
        return switch (@intFromEnum(reg)) {
            // zig fmt: off
            @intFromEnum(Register.rax)  ... @intFromEnum(Register.r15)   => .general_purpose,
            @intFromEnum(Register.eax)  ... @intFromEnum(Register.r15d)  => .general_purpose,
            @intFromEnum(Register.ax)   ... @intFromEnum(Register.r15w)  => .general_purpose,
            @intFromEnum(Register.al)   ... @intFromEnum(Register.r15b)  => .general_purpose,
            @intFromEnum(Register.ah)   ... @intFromEnum(Register.bh)    => .gphi,

            @intFromEnum(Register.zmm0) ... @intFromEnum(Register.zmm31) => .sse,
            @intFromEnum(Register.ymm0) ... @intFromEnum(Register.ymm31) => .sse,
            @intFromEnum(Register.xmm0) ... @intFromEnum(Register.xmm31) => .sse,
            @intFromEnum(Register.mm0)  ... @intFromEnum(Register.mm7)   => .mmx,
            @intFromEnum(Register.st0)  ... @intFromEnum(Register.st7)   => .x87,

            @intFromEnum(Register.es)   ... @intFromEnum(Register.gs)    => .segment,
            @intFromEnum(Register.rip)  ... @intFromEnum(Register.ip)    => .ip,
            @intFromEnum(Register.cr0)  ... @intFromEnum(Register.cr15)  => .cr,
            @intFromEnum(Register.dr0)  ... @intFromEnum(Register.dr15)  => .dr,

            else => unreachable,
            // zig fmt: on
        };
    }

    pub fn id(reg: Register) u7 {
        const base = switch (@intFromEnum(reg)) {
            // zig fmt: off
            @intFromEnum(Register.rax)  ... @intFromEnum(Register.r15)   => @intFromEnum(Register.rax),
            @intFromEnum(Register.eax)  ... @intFromEnum(Register.r15d)  => @intFromEnum(Register.eax),
            @intFromEnum(Register.ax)   ... @intFromEnum(Register.r15w)  => @intFromEnum(Register.ax),
            @intFromEnum(Register.al)   ... @intFromEnum(Register.r15b)  => @intFromEnum(Register.al),
            @intFromEnum(Register.ah)   ... @intFromEnum(Register.bh)    => @intFromEnum(Register.ah),

            @intFromEnum(Register.zmm0) ... @intFromEnum(Register.zmm31) => @intFromEnum(Register.zmm0) - 16,
            @intFromEnum(Register.ymm0) ... @intFromEnum(Register.ymm31) => @intFromEnum(Register.ymm0) - 16,
            @intFromEnum(Register.xmm0) ... @intFromEnum(Register.xmm31) => @intFromEnum(Register.xmm0) - 16,
            @intFromEnum(Register.mm0)  ... @intFromEnum(Register.mm7)   => @intFromEnum(Register.mm0)  - 48,
            @intFromEnum(Register.st0)  ... @intFromEnum(Register.st7)   => @intFromEnum(Register.st0)  - 56,
            @intFromEnum(Register.es)   ... @intFromEnum(Register.gs)    => @intFromEnum(Register.es)   - 64,
            @intFromEnum(Register.cr0)  ... @intFromEnum(Register.cr15)  => @intFromEnum(Register.cr0)  - 70,
            @intFromEnum(Register.dr0)  ... @intFromEnum(Register.dr15)  => @intFromEnum(Register.dr0)  - 86,

            else => unreachable,
            // zig fmt: on
        };
        return @intCast(@intFromEnum(reg) - base);
    }

    pub fn bitSize(reg: Register) u10 {
        return switch (@intFromEnum(reg)) {
            // zig fmt: off
            @intFromEnum(Register.rax)  ... @intFromEnum(Register.r15)   => 64,
            @intFromEnum(Register.eax)  ... @intFromEnum(Register.r15d)  => 32,
            @intFromEnum(Register.ax)   ... @intFromEnum(Register.r15w)  => 16,
            @intFromEnum(Register.al)   ... @intFromEnum(Register.r15b)  => 8,
            @intFromEnum(Register.ah)   ... @intFromEnum(Register.bh)    => 8,

            @intFromEnum(Register.zmm0) ... @intFromEnum(Register.zmm15) => 512,
            @intFromEnum(Register.ymm0) ... @intFromEnum(Register.ymm15) => 256,
            @intFromEnum(Register.xmm0) ... @intFromEnum(Register.xmm15) => 128,
            @intFromEnum(Register.mm0)  ... @intFromEnum(Register.mm7)   => 64,
            @intFromEnum(Register.st0)  ... @intFromEnum(Register.st7)   => 80,

            @intFromEnum(Register.es)   ... @intFromEnum(Register.gs)    => 16,

            @intFromEnum(Register.cr0)  ... @intFromEnum(Register.cr15)  => 64,
            @intFromEnum(Register.dr0)  ... @intFromEnum(Register.dr15)  => 64,

            else => unreachable,
            // zig fmt: on
        };
    }

    pub fn isExtended(reg: Register) bool {
        return switch (@intFromEnum(reg)) {
            // zig fmt: off
            @intFromEnum(Register.r8)  ... @intFromEnum(Register.r15)    => true,
            @intFromEnum(Register.r8d) ... @intFromEnum(Register.r15d)   => true,
            @intFromEnum(Register.r8w) ... @intFromEnum(Register.r15w)   => true,
            @intFromEnum(Register.r8b) ... @intFromEnum(Register.r15b)   => true,

            @intFromEnum(Register.zmm8) ... @intFromEnum(Register.zmm31) => true,
            @intFromEnum(Register.ymm8) ... @intFromEnum(Register.ymm31) => true,
            @intFromEnum(Register.xmm8) ... @intFromEnum(Register.xmm31) => true,

            @intFromEnum(Register.cr8)  ... @intFromEnum(Register.cr15)  => true,
            @intFromEnum(Register.dr8)  ... @intFromEnum(Register.dr15)  => true,

            else => false,
            // zig fmt: on
        };
    }

    pub fn enc(reg: Register) u5 {
        const base = switch (@intFromEnum(reg)) {
            // zig fmt: off
            @intFromEnum(Register.rax)  ... @intFromEnum(Register.r15)   => @intFromEnum(Register.rax),
            @intFromEnum(Register.eax)  ... @intFromEnum(Register.r15d)  => @intFromEnum(Register.eax),
            @intFromEnum(Register.ax)   ... @intFromEnum(Register.r15w)  => @intFromEnum(Register.ax),
            @intFromEnum(Register.al)   ... @intFromEnum(Register.r15b)  => @intFromEnum(Register.al),
            @intFromEnum(Register.ah)   ... @intFromEnum(Register.bh)    => @intFromEnum(Register.ah) - 4,

            @intFromEnum(Register.ymm0) ... @intFromEnum(Register.ymm15) => @intFromEnum(Register.ymm0),
            @intFromEnum(Register.xmm0) ... @intFromEnum(Register.xmm15) => @intFromEnum(Register.xmm0),
            @intFromEnum(Register.mm0)  ... @intFromEnum(Register.mm7)   => @intFromEnum(Register.mm0),
            @intFromEnum(Register.st0)  ... @intFromEnum(Register.st7)   => @intFromEnum(Register.st0),

            @intFromEnum(Register.es)   ... @intFromEnum(Register.gs)    => @intFromEnum(Register.es),

            @intFromEnum(Register.cr0)  ... @intFromEnum(Register.cr15)  => @intFromEnum(Register.cr0),
            @intFromEnum(Register.dr0)  ... @intFromEnum(Register.dr15)  => @intFromEnum(Register.dr0),

            else => unreachable,
            // zig fmt: on
        };
        return @truncate(@intFromEnum(reg) - base);
    }

    pub fn toBitSize(reg: Register, bit_size: u64) Register {
        return switch (bit_size) {
            8 => reg.to8(),
            16 => reg.to16(),
            32 => reg.to32(),
            64 => reg.to64(),
            128 => reg.to128(),
            256 => reg.to256(),
            else => unreachable,
        };
    }

    fn gpBase(reg: Register) u7 {
        return switch (@intFromEnum(reg)) {
            // zig fmt: off
            @intFromEnum(Register.rax)  ... @intFromEnum(Register.r15)   => @intFromEnum(Register.rax),
            @intFromEnum(Register.eax)  ... @intFromEnum(Register.r15d)  => @intFromEnum(Register.eax),
            @intFromEnum(Register.ax)   ... @intFromEnum(Register.r15w)  => @intFromEnum(Register.ax),
            @intFromEnum(Register.al)   ... @intFromEnum(Register.r15b)  => @intFromEnum(Register.al),
            @intFromEnum(Register.ah)   ... @intFromEnum(Register.bh)    => @intFromEnum(Register.ah),
            else => unreachable,
            // zig fmt: on
        };
    }

    pub fn to64(reg: Register) Register {
        return @enumFromInt(@intFromEnum(reg) - reg.gpBase() + @intFromEnum(Register.rax));
    }

    pub fn to32(reg: Register) Register {
        return @enumFromInt(@intFromEnum(reg) - reg.gpBase() + @intFromEnum(Register.eax));
    }

    pub fn to16(reg: Register) Register {
        return @enumFromInt(@intFromEnum(reg) - reg.gpBase() + @intFromEnum(Register.ax));
    }

    pub fn to8(reg: Register) Register {
        return switch (@intFromEnum(reg)) {
            else => @enumFromInt(@intFromEnum(reg) - reg.gpBase() + @intFromEnum(Register.al)),
            @intFromEnum(Register.ah)...@intFromEnum(Register.bh) => reg,
        };
    }

    fn sseBase(reg: Register) u8 {
        assert(reg.class() == .sse);
        return switch (@intFromEnum(reg)) {
            @intFromEnum(Register.zmm0)...@intFromEnum(Register.zmm31) => @intFromEnum(Register.zmm0),
            @intFromEnum(Register.ymm0)...@intFromEnum(Register.ymm31) => @intFromEnum(Register.ymm0),
            @intFromEnum(Register.xmm0)...@intFromEnum(Register.xmm31) => @intFromEnum(Register.xmm0),
            else => unreachable,
        };
    }

    pub fn to256(reg: Register) Register {
        return @enumFromInt(@intFromEnum(reg) - reg.sseBase() + @intFromEnum(Register.ymm0));
    }

    pub fn to128(reg: Register) Register {
        return @enumFromInt(@intFromEnum(reg) - reg.sseBase() + @intFromEnum(Register.xmm0));
    }

    /// DWARF register encoding
    pub fn dwarfNum(reg: Register) u6 {
        return switch (reg.class()) {
            .general_purpose, .gphi => if (reg.isExtended())
                reg.enc()
            else
                @as(u3, @truncate(@as(u24, 0o54673120) >> @as(u5, reg.enc()) * 3)),
            .sse => 17 + @as(u6, reg.enc()),
            .x87 => 33 + @as(u6, reg.enc()),
            .mmx => 41 + @as(u6, reg.enc()),
            .segment => 50 + @as(u6, reg.enc()),
            .ip => 16,
            .cr, .dr => unreachable,
        };
    }
};

test "Register id - different classes" {
    try expect(Register.al.id() == Register.ax.id());
    try expect(Register.ah.id() != Register.spl.id());
    try expect(Register.ax.id() == Register.eax.id());
    try expect(Register.eax.id() == Register.rax.id());

    try expect(Register.ymm0.id() == 0b10000);
    try expect(Register.ymm0.id() != Register.rax.id());
    try expect(Register.xmm0.id() == Register.ymm0.id());
    try expect(Register.xmm0.id() != Register.mm0.id());
    try expect(Register.mm0.id() != Register.st0.id());

    try expect(Register.es.id() == 0b110000);
}

test "Register enc - different classes" {
    try expect(Register.al.enc() == Register.ax.enc());
    try expect(Register.ah.enc() == Register.spl.enc());
    try expect(Register.ax.enc() == Register.eax.enc());
    try expect(Register.eax.enc() == Register.rax.enc());
    try expect(Register.ymm0.enc() == Register.rax.enc());
    try expect(Register.xmm0.enc() == Register.ymm0.enc());
    try expect(Register.es.enc() == Register.rax.enc());
}

test "Register classes" {
    try expect(Register.r11.class() == .general_purpose);
    try expect(Register.ymm11.class() == .sse);
    try expect(Register.mm3.class() == .mmx);
    try expect(Register.st3.class() == .x87);
    try expect(Register.fs.class() == .segment);
}

pub const FrameIndex = enum(u32) {
    // This index refers to the start of the arguments passed to this function
    args_frame,
    // This index refers to the return address pushed by a `call` and popped by a `ret`.
    ret_addr,
    // This index refers to the base pointer pushed in the prologue and popped in the epilogue.
    base_ptr,
    // This index refers to the entire stack frame.
    stack_frame,
    // This index refers to the start of the call frame for arguments passed to called functions
    call_frame,
    // Other indices are used for local variable stack slots
    _,

    pub const named_count = @typeInfo(FrameIndex).@"enum".fields.len;

    pub fn isNamed(fi: FrameIndex) bool {
        return @intFromEnum(fi) < named_count;
    }

    pub fn format(
        fi: FrameIndex,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        try writer.writeAll("FrameIndex");
        if (fi.isNamed()) {
            try writer.writeByte('.');
            try writer.writeAll(@tagName(fi));
        } else {
            try writer.writeByte('(');
            try std.fmt.formatType(@intFromEnum(fi), fmt, options, writer, 0);
            try writer.writeByte(')');
        }
    }
};

pub const FrameAddr = struct { index: FrameIndex, off: i32 = 0 };

pub const RegisterOffset = struct { reg: Register, off: i32 = 0 };

pub const SymbolOffset = struct { sym_index: u32, off: i32 = 0 };

pub const Memory = struct {
    base: Base = .none,
    mod: Mod = .{ .rm = .{} },

    pub const Base = union(enum(u3)) {
        none,
        reg: Register,
        frame: FrameIndex,
        table,
        reloc: u32,
        rip_inst: Mir.Inst.Index,

        pub const Tag = @typeInfo(Base).@"union".tag_type.?;
    };

    pub const Mod = union(enum(u1)) {
        rm: Rm,
        off: u64,

        pub const Rm = struct {
            size: Size = .none,
            index: Register = .none,
            scale: Scale = .@"1",
            disp: i32 = 0,
        };
    };

    pub const Size = enum(u4) {
        none,
        ptr,
        gpr,
        byte,
        word,
        dword,
        qword,
        tbyte,
        xword,
        yword,
        zword,

        pub fn fromSize(size: u32) Size {
            return switch (size) {
                1...1 => .byte,
                2...2 => .word,
                3...4 => .dword,
                5...8 => .qword,
                9...16 => .xword,
                17...32 => .yword,
                33...64 => .zword,
                else => unreachable,
            };
        }

        pub fn fromBitSize(bit_size: u64) Size {
            return switch (bit_size) {
                8 => .byte,
                16 => .word,
                32 => .dword,
                64 => .qword,
                80 => .tbyte,
                128 => .xword,
                256 => .yword,
                512 => .zword,
                else => unreachable,
            };
        }

        pub fn bitSize(s: Size, target: *const std.Target) u64 {
            return switch (s) {
                .none => 0,
                .ptr => target.ptrBitWidth(),
                .gpr => switch (target.cpu.arch) {
                    else => unreachable,
                    .x86 => 32,
                    .x86_64 => 64,
                },
                .byte => 8,
                .word => 16,
                .dword => 32,
                .qword => 64,
                .tbyte => 80,
                .xword => 128,
                .yword => 256,
                .zword => 512,
            };
        }

        pub fn format(
            s: Size,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) @TypeOf(writer).Error!void {
            if (s == .none) return;
            try writer.writeAll(@tagName(s));
            switch (s) {
                .none => unreachable,
                .ptr, .gpr => {},
                else => {
                    try writer.writeByte(' ');
                    try writer.writeAll("ptr");
                },
            }
        }
    };

    pub const Scale = enum(u2) {
        @"1",
        @"2",
        @"4",
        @"8",

        pub fn fromFactor(factor: u4) Scale {
            return switch (factor) {
                else => unreachable,
                1 => .@"1",
                2 => .@"2",
                4 => .@"4",
                8 => .@"8",
            };
        }

        pub fn toFactor(scale: Scale) u4 {
            return switch (scale) {
                .@"1" => 1,
                .@"2" => 2,
                .@"4" => 4,
                .@"8" => 8,
            };
        }

        pub fn fromLog2(log2: u2) Scale {
            return @enumFromInt(log2);
        }

        pub fn toLog2(scale: Scale) u2 {
            return @intFromEnum(scale);
        }
    };
};

pub const Immediate = union(enum) {
    signed: i32,
    unsigned: u64,
    reloc: SymbolOffset,

    pub fn u(x: u64) Immediate {
        return .{ .unsigned = x };
    }

    pub fn s(x: i32) Immediate {
        return .{ .signed = x };
    }

    pub fn rel(sym_off: SymbolOffset) Immediate {
        return .{ .reloc = sym_off };
    }

    pub fn format(
        imm: Immediate,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        switch (imm) {
            inline else => |int| try writer.print("{d}", .{int}),
            .reloc => |sym_off| try writer.print("Symbol({[sym_index]d}) + {[off]d}", sym_off),
        }
    }
};
