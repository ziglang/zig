const std = @import("std");
const expect = std.testing.expect;

extern fn powq(i64) i64;
extern fn div2(i64) i64;

test "call both imports" {
    try expect(powq(2) == 4);
    try expect(div2(4) == 2);
}
