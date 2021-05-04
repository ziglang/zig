const other = @import("pub_enum/other.zig");
const expect = @import("std").testing.expect;

test "pub enum" {
    try pubEnumTest(other.APubEnum.Two);
}
fn pubEnumTest(foo: other.APubEnum) !void {
    try expect(foo == other.APubEnum.Two);
}

test "cast with imported symbol" {
    try expect(@as(other.size_t, 42) == 42);
}
