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
};

// zig fmt: on

pub const callee_preserved_regs = [_]Register{ .eax, .ecx, .edx, .esi, .edi };
