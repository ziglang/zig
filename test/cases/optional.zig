const assert = @import("std").debug.assert;

pub const EmptyStruct = struct {};

test "optional pointer to size zero struct" {
    var e = EmptyStruct{};
    var o: ?*EmptyStruct = &e;
    assert(o != null);
}

test "equality compare nullable pointers" {
    testNullPtrsEql();
    comptime testNullPtrsEql();
}

fn testNullPtrsEql() void {
    var number: i32 = 1234;

    var x: ?*i32 = null;
    var y: ?*i32 = null;
    assert(x == y);
    y = &number;
    assert(x != y);
    assert(x != &number);
    assert(&number != x);
    x = &number;
    assert(x == y);
    assert(x == &number);
    assert(&number == x);
}
