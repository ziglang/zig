const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "miscompilation with bool return type" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var x: usize = 1;
    var y: bool = getFalse();
    _ = y;

    try expect(x == 1);
}

fn getFalse() bool {
    return false;
}
