// zig fmt: off
pub const Register = enum(u8) {
    // 0 through 7, 32-bit registers. id is int value
    eax, ecx, edx, ebx, esp, ebp, esi, edi, 

    // 8-15, 16-bit registers. id is int value - 8.
    ax, cx, dx, bx, sp, bp, si, di,
    
    // 16-23, 8-bit registers. id is int value - 16.
    al, bl, cl, dl, ah, ch, dh, bh,

    pub fn size(self: @This()) u7 {
        return switch (@enumToInt(self)) {
            0...7 => 32,
            8...15 => 16,
            16...23 => 8,
            else => unreachable,
        };
    }

    pub fn id(self: @This()) u3 {
        return @intCast(u4, switch (@enumToInt(self)) {
            0...7 => |i| i,
            8...15 => |i| i - 8,
            16...23 => |i| i - 16,
            else => unreachable,
        });
    }
    
};

// zig fmt: on
