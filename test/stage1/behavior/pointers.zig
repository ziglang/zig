const std = @import("std");
const expect = std.testing.expect;

test "dereference pointer" {
    comptime testDerefPtr();
    testDerefPtr();
}

fn testDerefPtr() void {
    var x: i32 = 1234;
    var y = &x;
    y.* += 1;
    expect(x == 1235);
}

test "pointer arithmetic" {
    var ptr = c"abcd";

    expect(ptr[0] == 'a');
    ptr += 1;
    expect(ptr[0] == 'b');
    ptr += 1;
    expect(ptr[0] == 'c');
    ptr += 1;
    expect(ptr[0] == 'd');
    ptr += 1;
    expect(ptr[0] == 0);
    ptr -= 1;
    expect(ptr[0] == 'd');
    ptr -= 1;
    expect(ptr[0] == 'c');
    ptr -= 1;
    expect(ptr[0] == 'b');
    ptr -= 1;
    expect(ptr[0] == 'a');
}

test "double pointer parsing" {
    comptime expect(PtrOf(PtrOf(i32)) == **i32);
}

fn PtrOf(comptime T: type) type {
    return *T;
}

test "assigning integer to C pointer" {
    var x: i32 = 0;
    var ptr: [*c]u8 = 0;
    var ptr2: [*c]u8 = x;
}

test "implicit cast single item pointer to C pointer and back" {
    var y: u8 = 11;
    var x: [*c]u8 = &y;
    var z: *u8 = x;
    z.* += 1;
    expect(y == 12);
}

test "C pointer comparison and arithmetic" {
    var one: usize = 1;
    var ptr1: [*c]u8 = 0;
    var ptr2 = ptr1 + 10;
    expect(ptr1 == 0);
    expect(ptr1 >= 0);
    expect(ptr1 <= 0);
    expect(ptr1 < 1);
    expect(ptr1 < one);
    expect(1 > ptr1);
    expect(one > ptr1);
    expect(ptr1 < ptr2);
    expect(ptr2 > ptr1);
    expect(ptr2 >= 10);
    expect(ptr2 == 10);
    expect(ptr2 <= 10);
    ptr2 -= 10;
    expect(ptr1 == ptr2);
}
