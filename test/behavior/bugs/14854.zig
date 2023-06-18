const testing = @import("std").testing;
const builtin = @import("builtin");

test {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try testing.expect(getGeneric(u8, getU8) == 123);
}

fn getU8() callconv(.C) u8 {
    return 123;
}

fn getGeneric(comptime T: type, supplier: fn () callconv(.C) T) T {
    return supplier();
}
