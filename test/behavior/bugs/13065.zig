const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

const U = union(enum) {
    array: [10]u32,
    other: u32,
};

test {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var x = U{ .array = undefined };

    x.array[1] = 0;
    const a = x.array;
    x.array[1] = 15;

    try expect(a[1] == 0);
}
