// from #7789 - crashed stage1 at ../src/stage1/analyze.cpp:7168

const std = @import("std");

test "basic add functionality" {
    // fails
    try std.testing.expect(comptime std.meta.eql(@typeInfo(opaque {}), @typeInfo(opaque {})));
}

// compile
//
