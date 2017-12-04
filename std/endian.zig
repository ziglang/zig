const mem = @import("mem.zig");
const builtin = @import("builtin");

pub fn swapIfLe(comptime T: type, x: T) -> T {
    swapIf(false, T, x)
}

pub fn swapIfBe(comptime T: type, x: T) -> T {
    swapIf(true, T, x)
}

pub fn swapIf(endian: builtin.Endian, comptime T: type, x: T) -> T {
    if (builtin.endian == endian) swap(T, x) else x
}

pub fn swap(comptime T: type, x: T) -> T {
    var buf: [@sizeOf(T)]u8 = undefined;
    mem.writeInt(buf[0..], x, false);
    return mem.readInt(buf, T, true);
}
