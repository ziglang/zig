const std = @import("std");
const expect = std.testing.expect;

const S = struct { a: usize };
test "lazy abi size used in comparison" {
    var rhs: i32 = 100;
    try expect(@sizeOf(S) < rhs);
}
