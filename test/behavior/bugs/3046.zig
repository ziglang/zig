const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

const SomeStruct = struct {
    field: i32,
};

fn couldFail() anyerror!i32 {
    return 1;
}

var some_struct: SomeStruct = undefined;

test "fixed" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    some_struct = SomeStruct{
        .field = couldFail() catch @as(i32, 0),
    };
    try expect(some_struct.field == 1);
}
