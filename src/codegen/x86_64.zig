const std = @import("std");
const Type = @import("../Type.zig");
const DW = std.dwarf;

// zig fmt: off

/// Definitions of all of the x64 registers. The order is semantically meaningful.
/// The registers are defined such that IDs go in descending order of 64-bit,
/// 32-bit, 16-bit, and then 8-bit, and each set contains exactly sixteen
/// registers. This results in some useful properties:
///
/// Any 64-bit register can be turned into its 32-bit form by adding 16, and
/// vice versa. This also works between 32-bit and 16-bit forms. With 8-bit, it
/// works for all except for sp, bp, si, and di, which do *not* have an 8-bit
/// form.
///
/// If (register & 8) is set, the register is extended.
///
/// The ID can be easily determined by figuring out what range the register is
/// in, and then subtracting the base.
pub const Register = enum(u8) {
    // 0 through 15, 64-bit registers. 8-15 are extended.
    // id is just the int value.
    rax, rcx, rdx, rbx, rsp, rbp, rsi, rdi,
    r8, r9, r10, r11, r12, r13, r14, r15,

    // 16 through 31, 32-bit registers. 24-31 are extended.
    // id is int value - 16.
    eax, ecx, edx, ebx, esp, ebp, esi, edi, 
    r8d, r9d, r10d, r11d, r12d, r13d, r14d, r15d,

    // 32-47, 16-bit registers. 40-47 are extended.
    // id is int value - 32.
    ax, cx, dx, bx, sp, bp, si, di,
    r8w, r9w, r10w, r11w, r12w, r13w, r14w, r15w,
    
    // 48-63, 8-bit registers. 56-63 are extended.
    // id is int value - 48.
    al, cl, dl, bl, ah, ch, dh, bh,
    r8b, r9b, r10b, r11b, r12b, r13b, r14b, r15b,

    /// Returns the bit-width of the register.
    pub fn size(self: Register) u7 {
        return switch (@enumToInt(self)) {
            0...15 => 64,
            16...31 => 32,
            32...47 => 16,
            48...64 => 8,
            else => unreachable,
        };
    }

    /// Returns whether the register is *extended*. Extended registers are the
    /// new registers added with amd64, r8 through r15. This also includes any
    /// other variant of access to those registers, such as r8b, r15d, and so
    /// on. This is needed because access to these registers requires special
    /// handling via the REX prefix, via the B or R bits, depending on context.
    pub fn isExtended(self: Register) bool {
        return @enumToInt(self) & 0x08 != 0;
    }

    /// This returns the 4-bit register ID, which is used in practically every
    /// opcode. Note that bit 3 (the highest bit) is *never* used directly in
    /// an instruction (@see isExtended), and requires special handling. The
    /// lower three bits are often embedded directly in instructions (such as
    /// the B8 variant of moves), or used in R/M bytes.
    pub fn id(self: Register) u4 {
        return @truncate(u4, @enumToInt(self));
    }

    /// Returns the index into `callee_preserved_regs`.
    pub fn allocIndex(self: Register) ?u4 {
        return switch (self) {
            .rax, .eax, .ax, .al => 0,
            .rcx, .ecx, .cx, .cl => 1,
            .rdx, .edx, .dx, .dl => 2,
            .rsi, .esi, .si  => 3,
            .rdi, .edi, .di => 4,
            .r8, .r8d, .r8w, .r8b => 5,
            .r9, .r9d, .r9w, .r9b => 6,
            .r10, .r10d, .r10w, .r10b => 7,
            .r11, .r11d, .r11w, .r11b => 8,
            else => null,
        };
    }

    /// Convert from any register to its 64 bit alias.
    pub fn to64(self: Register) Register {
        return @intToEnum(Register, self.id());
    }

    /// Convert from any register to its 32 bit alias.
    pub fn to32(self: Register) Register {
        return @intToEnum(Register, @as(u8, self.id()) + 16);
    }

    /// Convert from any register to its 16 bit alias.
    pub fn to16(self: Register) Register {
        return @intToEnum(Register, @as(u8, self.id()) + 32);
    }

    /// Convert from any register to its 8 bit alias.
    pub fn to8(self: Register) Register {
        return @intToEnum(Register, @as(u8, self.id()) + 48);
    }

    pub fn dwarfLocOp(self: Register) u8 {
        return switch (self.to64()) {
            .rax => DW.OP_reg0,
            .rdx => DW.OP_reg1,
            .rcx => DW.OP_reg2,
            .rbx => DW.OP_reg3,
            .rsi => DW.OP_reg4,
            .rdi => DW.OP_reg5,
            .rbp => DW.OP_reg6,
            .rsp => DW.OP_reg7,

            .r8 => DW.OP_reg8,
            .r9 => DW.OP_reg9,
            .r10 => DW.OP_reg10,
            .r11 => DW.OP_reg11,
            .r12 => DW.OP_reg12,
            .r13 => DW.OP_reg13,
            .r14 => DW.OP_reg14,
            .r15 => DW.OP_reg15,

            else => unreachable,
        };
    }
};

// zig fmt: on

/// These registers belong to the called function.
pub const callee_preserved_regs = [_]Register{ .rax, .rcx, .rdx, .rsi, .rdi, .r8, .r9, .r10, .r11 };
pub const c_abi_int_param_regs = [_]Register{ .rdi, .rsi, .rdx, .rcx, .r8, .r9 };
pub const c_abi_int_return_regs = [_]Register{ .rax, .rdx };

// TODO add these registers to the enum and populate dwarfLocOp
//    // Return Address register. This is stored in `0(%rsp, "")` and is not a physical register.
//    RA = (16, "RA"),
//
//    XMM0 = (17, "xmm0"),
//    XMM1 = (18, "xmm1"),
//    XMM2 = (19, "xmm2"),
//    XMM3 = (20, "xmm3"),
//    XMM4 = (21, "xmm4"),
//    XMM5 = (22, "xmm5"),
//    XMM6 = (23, "xmm6"),
//    XMM7 = (24, "xmm7"),
//
//    XMM8 = (25, "xmm8"),
//    XMM9 = (26, "xmm9"),
//    XMM10 = (27, "xmm10"),
//    XMM11 = (28, "xmm11"),
//    XMM12 = (29, "xmm12"),
//    XMM13 = (30, "xmm13"),
//    XMM14 = (31, "xmm14"),
//    XMM15 = (32, "xmm15"),
//
//    ST0 = (33, "st0"),
//    ST1 = (34, "st1"),
//    ST2 = (35, "st2"),
//    ST3 = (36, "st3"),
//    ST4 = (37, "st4"),
//    ST5 = (38, "st5"),
//    ST6 = (39, "st6"),
//    ST7 = (40, "st7"),
//
//    MM0 = (41, "mm0"),
//    MM1 = (42, "mm1"),
//    MM2 = (43, "mm2"),
//    MM3 = (44, "mm3"),
//    MM4 = (45, "mm4"),
//    MM5 = (46, "mm5"),
//    MM6 = (47, "mm6"),
//    MM7 = (48, "mm7"),
//
//    RFLAGS = (49, "rFLAGS"),
//    ES = (50, "es"),
//    CS = (51, "cs"),
//    SS = (52, "ss"),
//    DS = (53, "ds"),
//    FS = (54, "fs"),
//    GS = (55, "gs"),
//
//    FS_BASE = (58, "fs.base"),
//    GS_BASE = (59, "gs.base"),
//
//    TR = (62, "tr"),
//    LDTR = (63, "ldtr"),
//    MXCSR = (64, "mxcsr"),
//    FCW = (65, "fcw"),
//    FSW = (66, "fsw"),
//
//    XMM16 = (67, "xmm16"),
//    XMM17 = (68, "xmm17"),
//    XMM18 = (69, "xmm18"),
//    XMM19 = (70, "xmm19"),
//    XMM20 = (71, "xmm20"),
//    XMM21 = (72, "xmm21"),
//    XMM22 = (73, "xmm22"),
//    XMM23 = (74, "xmm23"),
//    XMM24 = (75, "xmm24"),
//    XMM25 = (76, "xmm25"),
//    XMM26 = (77, "xmm26"),
//    XMM27 = (78, "xmm27"),
//    XMM28 = (79, "xmm28"),
//    XMM29 = (80, "xmm29"),
//    XMM30 = (81, "xmm30"),
//    XMM31 = (82, "xmm31"),
//
//    K0 = (118, "k0"),
//    K1 = (119, "k1"),
//    K2 = (120, "k2"),
//    K3 = (121, "k3"),
//    K4 = (122, "k4"),
//    K5 = (123, "k5"),
//    K6 = (124, "k6"),
//    K7 = (125, "k7"),
