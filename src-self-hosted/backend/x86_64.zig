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

    pub fn size(self: @This()) u7 {
        return switch (@enumToInt(self)) {
            0...15 => 64,
            16...31 => 32,
            32...47 => 16,
            48...64 => 8,
            else => unreachable,
        };
    }

    pub fn isExtended(self: @This()) bool {
        return @enumToInt(self) & 0x08 != 0;
    }

    pub fn id(self: @This()) u4 {
        return @intCast(u4, switch (@enumToInt(self)) {
            0...15 => |i| i,
            16...31 => |i| i - 16,
            32...47 => |i| i - 32,
            48...64 => |i| i - 48,
            else => unreachable,
        });
    }
    
};

// zig fmt: on
