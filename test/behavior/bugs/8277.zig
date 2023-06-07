const std = @import("std");
const builtin = @import("builtin");

test "@sizeOf reified union zero-size payload fields" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    comptime {
        try std.testing.expect(0 == @sizeOf(@Type(@typeInfo(union {}))));
        try std.testing.expect(0 == @sizeOf(@Type(@typeInfo(union { a: void }))));
        if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
            try std.testing.expect(1 == @sizeOf(@Type(@typeInfo(union { a: void, b: void }))));
            try std.testing.expect(1 == @sizeOf(@Type(@typeInfo(union { a: void, b: void, c: void }))));
        } else {
            try std.testing.expect(0 == @sizeOf(@Type(@typeInfo(union { a: void, b: void }))));
            try std.testing.expect(0 == @sizeOf(@Type(@typeInfo(union { a: void, b: void, c: void }))));
        }
    }
}
