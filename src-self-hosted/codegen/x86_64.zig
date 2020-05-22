// zig fmt: off
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
    al, bl, cl, dl, ah, ch, dh, bh,
    r8b, r9b, r10b, r11b, r12b, r13b, r14b, r15b,

    /// Returns the bit-width of the register.
    pub fn size(self: @This()) u7 {
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
    pub fn isExtended(self: @This()) bool {
        return @enumToInt(self) & 0x08 != 0;
    }

    /// This returns the 4-bit register ID, which is used in practically every
    /// opcode. Note that bit 3 (the highest bit) is *never* used directly in
    /// an instruction (@see isExtended), and requires special handling. The
    /// lower three bits are often embedded directly in instructions (such as
    /// the B8 variant of moves), or used in R/M bytes.
    pub fn id(self: @This()) u4 {
        return @truncate(u4, @enumToInt(self));
    }
};

// zig fmt: on
