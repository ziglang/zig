const assertOrPanic = @import("std").debug.assertOrPanic;

pub const EmptyStruct = struct {};

test "optional pointer to size zero struct" {
    var e = EmptyStruct{};
    var o: ?*EmptyStruct = &e;
    assertOrPanic(o != null);
}

test "equality compare nullable pointers" {
    testNullPtrsEql();
    comptime testNullPtrsEql();
}

fn testNullPtrsEql() void {
    var number: i32 = 1234;

    var x: ?*i32 = null;
    var y: ?*i32 = null;
    assertOrPanic(x == y);
    y = &number;
    assertOrPanic(x != y);
    assertOrPanic(x != &number);
    assertOrPanic(&number != x);
    x = &number;
    assertOrPanic(x == y);
    assertOrPanic(x == &number);
    assertOrPanic(&number == x);
}
