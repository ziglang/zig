const other = @import("pub_enum/other.zig");
const expect = @import("std").testing.expect;

test "pub enum" {
    pubEnumTest(other.APubEnum.Two);
}
fn pubEnumTest(foo: other.APubEnum) void {
    expect(foo == other.APubEnum.Two);
}

test "cast with imported symbol" {
    expect(@as(other.size_t, 42) == 42);
}
