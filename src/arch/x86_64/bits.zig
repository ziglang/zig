const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const DW = std.dwarf;

pub const StringRepeat = enum(u3) { none, rep, repe, repz, repne, repnz };
pub const StringWidth = enum(u2) { b, w, d, q };

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
        };
    }
};

pub const Register = enum(u7) {
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

    ymm0, ymm1, ymm2,  ymm3,  ymm4,  ymm5,  ymm6,  ymm7,
    ymm8, ymm9, ymm10, ymm11, ymm12, ymm13, ymm14, ymm15,

    xmm0, xmm1, xmm2,  xmm3,  xmm4,  xmm5,  xmm6,  xmm7,
    xmm8, xmm9, xmm10, xmm11, xmm12, xmm13, xmm14, xmm15,

    es, cs, ss, ds, fs, gs,

    none,
    // zig fmt: on

    pub const Class = enum(u2) {
        general_purpose,
        floating_point,
        segment,
    };

    pub fn class(reg: Register) Class {
        return switch (@enumToInt(reg)) {
            // zig fmt: off
            @enumToInt(Register.rax)  ... @enumToInt(Register.r15)   => .general_purpose,
            @enumToInt(Register.eax)  ... @enumToInt(Register.r15d)  => .general_purpose,
            @enumToInt(Register.ax)   ... @enumToInt(Register.r15w)  => .general_purpose,
            @enumToInt(Register.al)   ... @enumToInt(Register.r15b)  => .general_purpose,
            @enumToInt(Register.ah)   ... @enumToInt(Register.bh)    => .general_purpose,

            @enumToInt(Register.ymm0) ... @enumToInt(Register.ymm15) => .floating_point,
            @enumToInt(Register.xmm0) ... @enumToInt(Register.xmm15) => .floating_point,

            @enumToInt(Register.es)   ... @enumToInt(Register.gs)    => .segment,

            else => unreachable,
            // zig fmt: on
        };
    }

    pub fn id(reg: Register) u6 {
        const base = switch (@enumToInt(reg)) {
            // zig fmt: off
            @enumToInt(Register.rax)  ... @enumToInt(Register.r15)   => @enumToInt(Register.rax),
            @enumToInt(Register.eax)  ... @enumToInt(Register.r15d)  => @enumToInt(Register.eax),
            @enumToInt(Register.ax)   ... @enumToInt(Register.r15w)  => @enumToInt(Register.ax),
            @enumToInt(Register.al)   ... @enumToInt(Register.r15b)  => @enumToInt(Register.al),
            @enumToInt(Register.ah)   ... @enumToInt(Register.bh)    => @enumToInt(Register.ah) - 4,

            @enumToInt(Register.ymm0) ... @enumToInt(Register.ymm15) => @enumToInt(Register.ymm0) - 16,
            @enumToInt(Register.xmm0) ... @enumToInt(Register.xmm15) => @enumToInt(Register.xmm0) - 16,

            @enumToInt(Register.es)   ... @enumToInt(Register.gs)    => @enumToInt(Register.es) - 32,

            else => unreachable,
            // zig fmt: on
        };
        return @intCast(u6, @enumToInt(reg) - base);
    }

    pub fn bitSize(reg: Register) u64 {
        return switch (@enumToInt(reg)) {
            // zig fmt: off
            @enumToInt(Register.rax)  ... @enumToInt(Register.r15)   => 64,
            @enumToInt(Register.eax)  ... @enumToInt(Register.r15d)  => 32,
            @enumToInt(Register.ax)   ... @enumToInt(Register.r15w)  => 16,
            @enumToInt(Register.al)   ... @enumToInt(Register.r15b)  => 8,
            @enumToInt(Register.ah)   ... @enumToInt(Register.bh)    => 8,

            @enumToInt(Register.ymm0) ... @enumToInt(Register.ymm15) => 256,
            @enumToInt(Register.xmm0) ... @enumToInt(Register.xmm15) => 128,

            @enumToInt(Register.es)   ... @enumToInt(Register.gs)    => 16,

            else => unreachable,
            // zig fmt: on
        };
    }

    pub fn isExtended(reg: Register) bool {
        return switch (@enumToInt(reg)) {
            // zig fmt: off
            @enumToInt(Register.r8)  ... @enumToInt(Register.r15)    => true,
            @enumToInt(Register.r8d) ... @enumToInt(Register.r15d)   => true,
            @enumToInt(Register.r8w) ... @enumToInt(Register.r15w)   => true,
            @enumToInt(Register.r8b) ... @enumToInt(Register.r15b)   => true,

            @enumToInt(Register.ymm8) ... @enumToInt(Register.ymm15) => true,
            @enumToInt(Register.xmm8) ... @enumToInt(Register.xmm15) => true,

            else => false,
            // zig fmt: on
        };
    }

    pub fn enc(reg: Register) u4 {
        const base = switch (@enumToInt(reg)) {
            // zig fmt: off
            @enumToInt(Register.rax)  ... @enumToInt(Register.r15)   => @enumToInt(Register.rax),
            @enumToInt(Register.eax)  ... @enumToInt(Register.r15d)  => @enumToInt(Register.eax),
            @enumToInt(Register.ax)   ... @enumToInt(Register.r15w)  => @enumToInt(Register.ax),
            @enumToInt(Register.al)   ... @enumToInt(Register.r15b)  => @enumToInt(Register.al),
            @enumToInt(Register.ah)   ... @enumToInt(Register.bh)    => @enumToInt(Register.ah) - 4,

            @enumToInt(Register.ymm0) ... @enumToInt(Register.ymm15) => @enumToInt(Register.ymm0),
            @enumToInt(Register.xmm0) ... @enumToInt(Register.xmm15) => @enumToInt(Register.xmm0),

            @enumToInt(Register.es)   ... @enumToInt(Register.gs)    => @enumToInt(Register.es),

            else => unreachable,
            // zig fmt: on
        };
        return @truncate(u4, @enumToInt(reg) - base);
    }

    pub fn lowEnc(reg: Register) u3 {
        return @truncate(u3, reg.enc());
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
        assert(reg.class() == .general_purpose);
        return switch (@enumToInt(reg)) {
            // zig fmt: off
            @enumToInt(Register.rax)  ... @enumToInt(Register.r15)   => @enumToInt(Register.rax),
            @enumToInt(Register.eax)  ... @enumToInt(Register.r15d)  => @enumToInt(Register.eax),
            @enumToInt(Register.ax)   ... @enumToInt(Register.r15w)  => @enumToInt(Register.ax),
            @enumToInt(Register.al)   ... @enumToInt(Register.r15b)  => @enumToInt(Register.al),
            @enumToInt(Register.ah)   ... @enumToInt(Register.bh)    => @enumToInt(Register.ah) - 4,
            else => unreachable,
            // zig fmt: on
        };
    }

    pub fn to64(reg: Register) Register {
        return @intToEnum(Register, @enumToInt(reg) - reg.gpBase() + @enumToInt(Register.rax));
    }

    pub fn to32(reg: Register) Register {
        return @intToEnum(Register, @enumToInt(reg) - reg.gpBase() + @enumToInt(Register.eax));
    }

    pub fn to16(reg: Register) Register {
        return @intToEnum(Register, @enumToInt(reg) - reg.gpBase() + @enumToInt(Register.ax));
    }

    pub fn to8(reg: Register) Register {
        return @intToEnum(Register, @enumToInt(reg) - reg.gpBase() + @enumToInt(Register.al));
    }

    fn fpBase(reg: Register) u7 {
        assert(reg.class() == .floating_point);
        return switch (@enumToInt(reg)) {
            @enumToInt(Register.ymm0)...@enumToInt(Register.ymm15) => @enumToInt(Register.ymm0),
            @enumToInt(Register.xmm0)...@enumToInt(Register.xmm15) => @enumToInt(Register.xmm0),
            else => unreachable,
        };
    }

    pub fn to256(reg: Register) Register {
        return @intToEnum(Register, @enumToInt(reg) - reg.fpBase() + @enumToInt(Register.ymm0));
    }

    pub fn to128(reg: Register) Register {
        return @intToEnum(Register, @enumToInt(reg) - reg.fpBase() + @enumToInt(Register.xmm0));
    }

    pub fn dwarfLocOp(reg: Register) u8 {
        return switch (reg.class()) {
            .general_purpose => switch (reg.to64()) {
                .rax => DW.OP.reg0,
                .rdx => DW.OP.reg1,
                .rcx => DW.OP.reg2,
                .rbx => DW.OP.reg3,
                .rsi => DW.OP.reg4,
                .rdi => DW.OP.reg5,
                .rbp => DW.OP.reg6,
                .rsp => DW.OP.reg7,
                else => @intCast(u8, @enumToInt(reg) - reg.gpBase()) + DW.OP.reg0,
            },
            .floating_point => @intCast(u8, @enumToInt(reg) - reg.fpBase()) + DW.OP.reg17,
            else => unreachable,
        };
    }

    /// DWARF encodings that push a value onto the DWARF stack that is either
    /// the contents of a register or the result of adding the contents a given
    /// register to a given signed offset.
    pub fn dwarfLocOpDeref(reg: Register) u8 {
        return switch (reg.class()) {
            .general_purpose => switch (reg.to64()) {
                .rax => DW.OP.breg0,
                .rdx => DW.OP.breg1,
                .rcx => DW.OP.breg2,
                .rbx => DW.OP.breg3,
                .rsi => DW.OP.breg4,
                .rdi => DW.OP.breg5,
                .rbp => DW.OP.breg6,
                .rsp => DW.OP.breg7,
                else => @intCast(u8, @enumToInt(reg) - reg.gpBase()) + DW.OP.breg0,
            },
            .floating_point => @intCast(u8, @enumToInt(reg) - reg.fpBase()) + DW.OP.breg17,
            else => unreachable,
        };
    }
};

test "Register id - different classes" {
    try expect(Register.al.id() == Register.ax.id());
    try expect(Register.ah.id() == Register.spl.id());
    try expect(Register.ax.id() == Register.eax.id());
    try expect(Register.eax.id() == Register.rax.id());

    try expect(Register.ymm0.id() == 0b10000);
    try expect(Register.ymm0.id() != Register.rax.id());
    try expect(Register.xmm0.id() == Register.ymm0.id());

    try expect(Register.es.id() == 0b100000);
}

test "Register enc - different classes" {
    try expect(Register.al.enc() == Register.ax.enc());
    try expect(Register.ax.enc() == Register.eax.enc());
    try expect(Register.eax.enc() == Register.rax.enc());
    try expect(Register.ymm0.enc() == Register.rax.enc());
    try expect(Register.xmm0.enc() == Register.ymm0.enc());
    try expect(Register.es.enc() == Register.rax.enc());
}

test "Register classes" {
    try expect(Register.r11.class() == .general_purpose);
    try expect(Register.ymm11.class() == .floating_point);
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

    pub const named_count = @typeInfo(FrameIndex).Enum.fields.len;

    pub fn isNamed(fi: FrameIndex) bool {
        return @enumToInt(fi) < named_count;
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
            try std.fmt.formatType(@enumToInt(fi), fmt, options, writer, 0);
            try writer.writeByte(')');
        }
    }
};

pub const Memory = union(enum) {
    sib: Sib,
    rip: Rip,
    moffs: Moffs,

    pub const Base = union(enum) {
        none,
        reg: Register,
        frame: FrameIndex,

        pub const Tag = @typeInfo(Base).Union.tag_type.?;

        pub fn isExtended(self: Base) bool {
            return switch (self) {
                .none, .frame => false, // neither rsp nor rbp are extended
                .reg => |reg| reg.isExtended(),
            };
        }
    };

    pub const ScaleIndex = struct {
        scale: u4,
        index: Register,

        const none = ScaleIndex{ .scale = 0, .index = undefined };
    };

    pub const PtrSize = enum {
        byte,
        word,
        dword,
        qword,
        tbyte,
        dqword,

        pub fn fromSize(size: u32) PtrSize {
            return switch (size) {
                1...1 => .byte,
                2...2 => .word,
                3...4 => .dword,
                5...8 => .qword,
                9...16 => .dqword,
                else => unreachable,
            };
        }

        pub fn fromBitSize(bit_size: u64) PtrSize {
            return switch (bit_size) {
                8 => .byte,
                16 => .word,
                32 => .dword,
                64 => .qword,
                80 => .tbyte,
                128 => .dqword,
                else => unreachable,
            };
        }

        pub fn bitSize(s: PtrSize) u64 {
            return switch (s) {
                .byte => 8,
                .word => 16,
                .dword => 32,
                .qword => 64,
                .tbyte => 80,
                .dqword => 128,
            };
        }
    };

    pub const Sib = struct {
        ptr_size: PtrSize,
        base: Base,
        scale_index: ScaleIndex,
        disp: i32,
    };

    pub const Rip = struct {
        ptr_size: PtrSize,
        disp: i32,
    };

    pub const Moffs = struct {
        seg: Register,
        offset: u64,
    };

    pub fn moffs(reg: Register, offset: u64) Memory {
        assert(reg.class() == .segment);
        return .{ .moffs = .{ .seg = reg, .offset = offset } };
    }

    pub fn sib(ptr_size: PtrSize, args: struct {
        disp: i32 = 0,
        base: Base = .none,
        scale_index: ?ScaleIndex = null,
    }) Memory {
        if (args.scale_index) |si| assert(std.math.isPowerOfTwo(si.scale));
        return .{ .sib = .{
            .base = args.base,
            .disp = args.disp,
            .ptr_size = ptr_size,
            .scale_index = if (args.scale_index) |si| si else ScaleIndex.none,
        } };
    }

    pub fn rip(ptr_size: PtrSize, disp: i32) Memory {
        return .{ .rip = .{ .ptr_size = ptr_size, .disp = disp } };
    }

    pub fn isSegmentRegister(mem: Memory) bool {
        return switch (mem) {
            .moffs => true,
            .rip => false,
            .sib => |s| switch (s.base) {
                .none, .frame => false,
                .reg => |reg| reg.class() == .segment,
            },
        };
    }

    pub fn base(mem: Memory) Base {
        return switch (mem) {
            .moffs => |m| .{ .reg = m.seg },
            .sib => |s| s.base,
            .rip => .none,
        };
    }

    pub fn scaleIndex(mem: Memory) ?ScaleIndex {
        return switch (mem) {
            .moffs, .rip => null,
            .sib => |s| if (s.scale_index.scale > 0) s.scale_index else null,
        };
    }

    pub fn bitSize(mem: Memory) u64 {
        return switch (mem) {
            .rip => |r| r.ptr_size.bitSize(),
            .sib => |s| s.ptr_size.bitSize(),
            .moffs => 64,
        };
    }
};

pub const Immediate = union(enum) {
    signed: i32,
    unsigned: u64,

    pub fn u(x: u64) Immediate {
        return .{ .unsigned = x };
    }

    pub fn s(x: i32) Immediate {
        return .{ .signed = x };
    }

    pub fn asUnsigned(imm: Immediate, bit_size: u64) u64 {
        return switch (imm) {
            .signed => |x| switch (bit_size) {
                1, 8 => @bitCast(u8, @intCast(i8, x)),
                16 => @bitCast(u16, @intCast(i16, x)),
                32, 64 => @bitCast(u32, x),
                else => unreachable,
            },
            .unsigned => |x| switch (bit_size) {
                1, 8 => @intCast(u8, x),
                16 => @intCast(u16, x),
                32 => @intCast(u32, x),
                64 => x,
                else => unreachable,
            },
        };
    }
};
