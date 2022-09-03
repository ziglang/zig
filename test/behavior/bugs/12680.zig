const std = @import("std");
const expectEqual = std.testing.expectEqual;
const other_file =  @import("12680_other_file.zig");

extern fn test_func() callconv(.C) usize;

test "export a function twice" {
    // If it exports the function correctly, `test_func` and `testFunc` will points to the same address.
    try expectEqual(test_func(), other_file.testFunc());
}
