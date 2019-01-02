const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const builtin = @import("builtin");

test "compile time recursion" {
    assertOrPanic(some_data.len == 21);
}
var some_data: [@intCast(usize, fibonacci(7))]u8 = undefined;
fn fibonacci(x: i32) i32 {
    if (x <= 1) return 1;
    return fibonacci(x - 1) + fibonacci(x - 2);
}

fn unwrapAndAddOne(blah: ?i32) i32 {
    return blah.? + 1;
}
const should_be_1235 = unwrapAndAddOne(1234);
test "static add one" {
    assertOrPanic(should_be_1235 == 1235);
}

test "inlined loop" {
    comptime var i = 0;
    comptime var sum = 0;
    inline while (i <= 5) : (i += 1)
        sum += i;
    assertOrPanic(sum == 15);
}

fn gimme1or2(comptime a: bool) i32 {
    const x: i32 = 1;
    const y: i32 = 2;
    comptime var z: i32 = if (a) x else y;
    return z;
}
test "inline variable gets result of const if" {
    assertOrPanic(gimme1or2(true) == 1);
    assertOrPanic(gimme1or2(false) == 2);
}

test "static function evaluation" {
    assertOrPanic(statically_added_number == 3);
}
const statically_added_number = staticAdd(1, 2);
fn staticAdd(a: i32, b: i32) i32 {
    return a + b;
}

