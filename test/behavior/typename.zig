const std = @import("std");
const expect = std.testing.expect;
const expectEqualSlices = std.testing.expectEqualSlices;

test "slice" {
    try expectEqualSlices(u8, "[]u8", @typeName([]u8));
}
