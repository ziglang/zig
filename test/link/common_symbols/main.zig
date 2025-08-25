const std = @import("std");
const expect = std.testing.expect;

extern fn common_defined_externally() c_int;
extern fn incr_i() void;
extern fn add_to_i_and_j(x: c_int) c_int;

test "undef shadows common symbol: issue #9937" {
    try expect(common_defined_externally() == 0);
}

test "import C common symbols" {
    incr_i();
    const res = add_to_i_and_j(2);
    try expect(res == 5);
}
