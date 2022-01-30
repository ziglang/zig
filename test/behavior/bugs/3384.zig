const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "resolve array slice using builtin" {
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;

    try expect(@hasDecl(@This(), "std") == true);
    try expect(@hasDecl(@This(), "std"[0..0]) == false);
    try expect(@hasDecl(@This(), "std"[0..1]) == false);
    try expect(@hasDecl(@This(), "std"[0..2]) == false);
    try expect(@hasDecl(@This(), "std"[0..3]) == true);
    try expect(@hasDecl(@This(), "std"[0..]) == true);
}
