const std = @import("std");
const expect = std.testing.expect;
const builtin = @import("builtin");

const S = struct {
    p: *S,
};
test "bug 2006" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    var a: S = undefined;
    a = S{ .p = undefined };
    try expect(@sizeOf(S) != 0);
    if (@import("builtin").zig_backend != .stage1) {
        // It is an accepted proposal to make `@sizeOf` for pointers independent
        // of whether the element type is zero bits.
        // This language change has not been implemented in stage1.
        try expect(@sizeOf(*void) == @sizeOf(*i32));
    } else {
        try expect(@sizeOf(*void) == 0);
    }
}
