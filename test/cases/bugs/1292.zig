const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

comptime {
    var x: u32 = 0x1a2b3c4d;
    var s = @ptrCast([*]u8, &x)[0..@sizeOf(u32)];
    if (builtin.cpu.arch.endian() == std.builtin.Endian.Big) {
        assert(s[0] == 0x1a);
        assert(s[1] == 0x2b);
        assert(s[2] == 0x3c);
        assert(s[3] == 0x4d);
    } else {
        assert(s[0] == 0x4d);
        assert(s[1] == 0x3c);
        assert(s[2] == 0x2b);
        assert(s[3] == 0x1a);
    }
}

// run
// is_test=1
// backend=stage2
