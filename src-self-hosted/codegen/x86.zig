const std = @import("std");
const DW = std.dwarf;

// zig fmt: off
pub const Register = enum(u8) {
    // 0 through 7, 32-bit registers. id is int value
    eax, ecx, edx, ebx, esp, ebp, esi, edi, 

    // 8-15, 16-bit registers. id is int value - 8.
    ax, cx, dx, bx, sp, bp, si, di,
    
    // 16-23, 8-bit registers. id is int value - 16.
    al, cl, dl, bl, ah, ch, dh, bh,

    /// Returns the bit-width of the register.
    pub fn size(self: @This()) u7 {
        return switch (@enumToInt(self)) {
            0...7 => 32,
            8...15 => 16,
            16...23 => 8,
            else => unreachable,
        };
    }

    /// Returns the register's id. This is used in practically every opcode the
    /// x86 has. It is embedded in some instructions, such as the `B8 +rd` move
    /// instruction, and is used in the R/M byte.
    pub fn id(self: @This()) u3 {
        return @truncate(u3, @enumToInt(self));
    }

    /// Returns the index into `callee_preserved_regs`.
    pub fn allocIndex(self: Register) ?u4 {
        return switch (self) {
            .eax, .ax, .al => 0,
            .ecx, .cx, .cl => 1,
            .edx, .dx, .dl => 2,
            .esi, .si  => 3,
            .edi, .di => 4,
            else => null,
        };
    }

    /// Convert from any register to its 32 bit alias.
    pub fn to32(self: Register) Register {
        return @intToEnum(Register, @as(u8, self.id()));
    }

    /// Convert from any register to its 16 bit alias.
    pub fn to16(self: Register) Register {
        return @intToEnum(Register, @as(u8, self.id()) + 8);
    }

    /// Convert from any register to its 8 bit alias.
    pub fn to8(self: Register) Register {
        return @intToEnum(Register, @as(u8, self.id()) + 16);
    }


    pub fn dwarfLocOp(reg: Register) u8 {
        return switch (reg.to32()) {
            .eax => DW.OP_reg0,
            .ecx => DW.OP_reg1,
            .edx => DW.OP_reg2,
            .ebx => DW.OP_reg3,
            .esp => DW.OP_reg4,
            .ebp => DW.OP_reg5,
            .esi => DW.OP_reg6,
            .edi => DW.OP_reg7,
            else => unreachable,
        };
    }
};

// zig fmt: on

pub const callee_preserved_regs = [_]Register{ .eax, .ecx, .edx, .esi, .edi };

// TODO add these to Register enum and corresponding dwarfLocOp
//  // Return Address register. This is stored in `0(%esp, "")` and is not a physical register.
//  RA = (8, "RA"),
//
//  ST0 = (11, "st0"),
//  ST1 = (12, "st1"),
//  ST2 = (13, "st2"),
//  ST3 = (14, "st3"),
//  ST4 = (15, "st4"),
//  ST5 = (16, "st5"),
//  ST6 = (17, "st6"),
//  ST7 = (18, "st7"),
//
//  XMM0 = (21, "xmm0"),
//  XMM1 = (22, "xmm1"),
//  XMM2 = (23, "xmm2"),
//  XMM3 = (24, "xmm3"),
//  XMM4 = (25, "xmm4"),
//  XMM5 = (26, "xmm5"),
//  XMM6 = (27, "xmm6"),
//  XMM7 = (28, "xmm7"),
//
//  MM0 = (29, "mm0"),
//  MM1 = (30, "mm1"),
//  MM2 = (31, "mm2"),
//  MM3 = (32, "mm3"),
//  MM4 = (33, "mm4"),
//  MM5 = (34, "mm5"),
//  MM6 = (35, "mm6"),
//  MM7 = (36, "mm7"),
//
//  MXCSR = (39, "mxcsr"),
//
//  ES = (40, "es"),
//  CS = (41, "cs"),
//  SS = (42, "ss"),
//  DS = (43, "ds"),
//  FS = (44, "fs"),
//  GS = (45, "gs"),
//
//  TR = (48, "tr"),
//  LDTR = (49, "ldtr"),
//
//  FS_BASE = (93, "fs.base"),
//  GS_BASE = (94, "gs.base"),
