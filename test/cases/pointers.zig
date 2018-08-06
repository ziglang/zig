const std = @import("std");
const assert = std.debug.assert;

test "dereference pointer" {
    comptime testDerefPtr();
    testDerefPtr();
}

fn testDerefPtr() void {
    var x: i32 = 1234;
    var y = &x;
    y.* += 1;
    assert(x == 1235);
}

test "pointer arithmetic" {
    var ptr = c"abcd";

    assert(ptr[0] == 'a');
    ptr += 1;
    assert(ptr[0] == 'b');
    ptr += 1;
    assert(ptr[0] == 'c');
    ptr += 1;
    assert(ptr[0] == 'd');
    ptr += 1;
    assert(ptr[0] == 0);
    ptr -= 1;
    assert(ptr[0] == 'd');
    ptr -= 1;
    assert(ptr[0] == 'c');
    ptr -= 1;
    assert(ptr[0] == 'b');
    ptr -= 1;
    assert(ptr[0] == 'a');
}

test "double pointer parsing" {
    comptime assert(PtrOf(PtrOf(i32)) == **i32);
}

fn PtrOf(comptime T: type) type {
    return *T;
}
