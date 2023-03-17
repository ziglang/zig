const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

test "slicing zero length array field of struct" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const S = struct {
        a: [0]usize,
        fn foo(self: *@This(), start: usize, end: usize) []usize {
            return self.a[start..end];
        }
    };
    var s: S = undefined;
    try testing.expect(s.foo(0, 0).len == 0);
}
