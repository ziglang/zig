const std = @import("std");
const expect = std.testing.expect;

test "resolve array slice using builtin" {
    expect(@hasDecl(@This(), "std") == true);
    expect(@hasDecl(@This(), "std"[0..0]) == false);
    expect(@hasDecl(@This(), "std"[0..1]) == false);
    expect(@hasDecl(@This(), "std"[0..2]) == false);
    expect(@hasDecl(@This(), "std"[0..3]) == true);
    expect(@hasDecl(@This(), "std"[0..]) == true);
}
