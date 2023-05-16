const std = @import("std");
const expectEqual = std.testing.expectEqual;
const other_file = @import("12680_other_file.zig");
const builtin = @import("builtin");

extern fn test_func() callconv(.C) usize;

test "export a function twice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.os.tag == .macos and builtin.zig_backend == .stage2_c) {
        // TODO: test.c: error: aliases are not supported on darwin
        return error.SkipZigTest;
    }

    // If it exports the function correctly, `test_func` and `testFunc` will points to the same address.
    try expectEqual(test_func(), other_file.testFunc());
}
