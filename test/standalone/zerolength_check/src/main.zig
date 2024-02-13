const std = @import("std");

test {
    const dest = foo();
    const source = foo();

    @memcpy(dest, source);
    @memset(dest, 4);
    @memset(dest, undefined);

    const dest2 = foo2();
    @memset(dest2, 0);
}

fn foo() []u8 {
    const ptr = comptime std.mem.alignBackward(usize, std.math.maxInt(usize), 1);
    return @as([*]align(1) u8, @ptrFromInt(ptr))[0..0];
}

fn foo2() []u64 {
    const ptr = comptime std.mem.alignBackward(usize, std.math.maxInt(usize), 1);
    return @as([*]align(1) u64, @ptrFromInt(ptr))[0..0];
}
