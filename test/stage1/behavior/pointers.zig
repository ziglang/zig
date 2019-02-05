const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;

test "dereference pointer" {
    comptime testDerefPtr();
    testDerefPtr();
}

fn testDerefPtr() void {
    var x: i32 = 1234;
    var y = &x;
    y.* += 1;
    assertOrPanic(x == 1235);
}

test "pointer arithmetic" {
    var ptr = c"abcd";

    assertOrPanic(ptr[0] == 'a');
    ptr += 1;
    assertOrPanic(ptr[0] == 'b');
    ptr += 1;
    assertOrPanic(ptr[0] == 'c');
    ptr += 1;
    assertOrPanic(ptr[0] == 'd');
    ptr += 1;
    assertOrPanic(ptr[0] == 0);
    ptr -= 1;
    assertOrPanic(ptr[0] == 'd');
    ptr -= 1;
    assertOrPanic(ptr[0] == 'c');
    ptr -= 1;
    assertOrPanic(ptr[0] == 'b');
    ptr -= 1;
    assertOrPanic(ptr[0] == 'a');
}

test "double pointer parsing" {
    comptime assertOrPanic(PtrOf(PtrOf(i32)) == **i32);
}

fn PtrOf(comptime T: type) type {
    return *T;
}
