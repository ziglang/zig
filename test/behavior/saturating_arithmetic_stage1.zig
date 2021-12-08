const std = @import("std");
const expect = std.testing.expect;

test "saturating shl uses the LHS type" {
    const lhs_const: u8 = 1;
    var lhs_var: u8 = 1;

    const rhs_const: usize = 8;
    var rhs_var: usize = 8;

    try expect((lhs_const <<| 8) == 255);
    try expect((lhs_const <<| rhs_const) == 255);
    try expect((lhs_const <<| rhs_var) == 255);

    try expect((lhs_var <<| 8) == 255);
    try expect((lhs_var <<| rhs_const) == 255);
    try expect((lhs_var <<| rhs_var) == 255);

    try expect((@as(u8, 1) <<| 8) == 255);
    try expect((@as(u8, 1) <<| rhs_const) == 255);
    try expect((@as(u8, 1) <<| rhs_var) == 255);
}
