const std = @import("std");
const math = std.math;
const testing = std.testing;

test "fn reflection" {
    try testing.expect(@typeInfo(@TypeOf(testing.expect)).@"fn".params[0].type.? == bool);
    try testing.expect(@typeInfo(@TypeOf(testing.tmpDir)).@"fn".return_type.? == testing.TmpDir);

    try testing.expect(@typeInfo(@TypeOf(math.Log2Int)).@"fn".is_generic);
}

// test
