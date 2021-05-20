const std = @import("std");
const expect = std.testing.expect;

test "resolve array slice using builtin" {
    try expect(@hasDecl(@This(), "std") == true);
    try expect(@hasDecl(@This(), "std"[0..0]) == false);
    try expect(@hasDecl(@This(), "std"[0..1]) == false);
    try expect(@hasDecl(@This(), "std"[0..2]) == false);
    try expect(@hasDecl(@This(), "std"[0..3]) == true);
    try expect(@hasDecl(@This(), "std"[0..]) == true);
}
