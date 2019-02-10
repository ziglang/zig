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
