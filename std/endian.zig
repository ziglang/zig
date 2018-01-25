const mem = @import("mem.zig");
const builtin = @import("builtin");

pub fn swapIfLe(comptime T: type, x: T) T {
    return swapIf(builtin.Endian.Little, T, x);
}

pub fn swapIfBe(comptime T: type, x: T) T {
    return swapIf(builtin.Endian.Big, T, x);
}

pub fn swapIf(endian: builtin.Endian, comptime T: type, x: T) T {
    return if (builtin.endian == endian) swap(T, x) else x;
}

pub fn swap(comptime T: type, x: T) T {
    var buf: [@sizeOf(T)]u8 = undefined;
    mem.writeInt(buf[0..], x, builtin.Endian.Little);
    return mem.readInt(buf, T, builtin.Endian.Big);
}

test "swap" {
    const debug = @import("debug/index.zig");
    debug.assert(swap(u32, 0xDEADBEEF) == 0xEFBEADDE);
}
