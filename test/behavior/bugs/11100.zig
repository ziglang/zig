const std = @import("std");
const builtin = @import("builtin");

pub fn do() bool {
    inline for (.{"a"}) |_| {
        if (true) return false;
    }
    return true;
}

test "bug" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try std.testing.expect(!do());
}
