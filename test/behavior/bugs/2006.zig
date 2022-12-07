const std = @import("std");
const expect = std.testing.expect;
const builtin = @import("builtin");

const S = struct {
    p: *S,
};
test "bug 2006" {
    var a: S = undefined;
    a = S{ .p = undefined };
    try expect(@sizeOf(S) != 0);
    try expect(@sizeOf(*void) == @sizeOf(*i32));
}
