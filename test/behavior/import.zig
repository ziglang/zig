const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const a_namespace = @import("import/a_namespace.zig");

test "call fn via namespace lookup" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try expect(@as(i32, 1234) == a_namespace.foo());
}

test "importing the same thing gives the same import" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try expect(@import("std") == @import("std"));
}

test "import in non-toplevel scope" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        usingnamespace @import("import/a_namespace.zig");
    };
    try expect(@as(i32, 1234) == S.foo());
}

test "import empty file" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    _ = @import("import/empty.zig");
}
