const std = @import("std");
const expect = std.testing.expect;

const S = struct {
    p: *S,
};
test "bug 2006" {
    var a: S = undefined;
    a = S{ .p = undefined };
    expect(@sizeOf(S) != 0);
    expect(@sizeOf(*void) == 0);
}
