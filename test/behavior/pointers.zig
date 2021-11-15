const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectError = testing.expectError;

test "dereference pointer" {
    comptime try testDerefPtr();
    try testDerefPtr();
}

fn testDerefPtr() !void {
    var x: i32 = 1234;
    var y = &x;
    y.* += 1;
    try expect(x == 1235);
}

test "pointer arithmetic" {
    var ptr: [*]const u8 = "abcd";

    try expect(ptr[0] == 'a');
    ptr += 1;
    try expect(ptr[0] == 'b');
    ptr += 1;
    try expect(ptr[0] == 'c');
    ptr += 1;
    try expect(ptr[0] == 'd');
    ptr += 1;
    try expect(ptr[0] == 0);
    ptr -= 1;
    try expect(ptr[0] == 'd');
    ptr -= 1;
    try expect(ptr[0] == 'c');
    ptr -= 1;
    try expect(ptr[0] == 'b');
    ptr -= 1;
    try expect(ptr[0] == 'a');
}

test "double pointer parsing" {
    comptime try expect(PtrOf(PtrOf(i32)) == **i32);
}

fn PtrOf(comptime T: type) type {
    return *T;
}

test "implicit cast single item pointer to C pointer and back" {
    var y: u8 = 11;
    var x: [*c]u8 = &y;
    var z: *u8 = x;
    z.* += 1;
    try expect(y == 12);
}

test "initialize const optional C pointer to null" {
    const a: ?[*c]i32 = null;
    try expect(a == null);
    comptime try expect(a == null);
}

test "assigning integer to C pointer" {
    var x: i32 = 0;
    var y: i32 = 1;
    var ptr: [*c]u8 = 0;
    var ptr2: [*c]u8 = x;
    var ptr3: [*c]u8 = 1;
    var ptr4: [*c]u8 = y;

    try expect(ptr == ptr2);
    try expect(ptr3 == ptr4);
    try expect(ptr3 > ptr and ptr4 > ptr2 and y > x);
    try expect(1 > ptr and y > ptr2 and 0 < ptr3 and x < ptr4);
}

test "C pointer comparison and arithmetic" {
    const S = struct {
        fn doTheTest() !void {
            var ptr1: [*c]u32 = 0;
            var ptr2 = ptr1 + 10;
            try expect(ptr1 == 0);
            try expect(ptr1 >= 0);
            try expect(ptr1 <= 0);
            // expect(ptr1 < 1);
            // expect(ptr1 < one);
            // expect(1 > ptr1);
            // expect(one > ptr1);
            try expect(ptr1 < ptr2);
            try expect(ptr2 > ptr1);
            try expect(ptr2 >= 40);
            try expect(ptr2 == 40);
            try expect(ptr2 <= 40);
            ptr2 -= 10;
            try expect(ptr1 == ptr2);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}
