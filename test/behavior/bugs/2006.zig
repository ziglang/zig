const std = @import("std");
const expect = std.testing.expect;
const builtin = @import("builtin");

const S = struct {
    p: *S,
};
test "bug 2006" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var a: S = undefined;
    a = S{ .p = undefined };
    try expect(@sizeOf(S) != 0);
    try expect(@sizeOf(*void) == @sizeOf(*i32));
}
