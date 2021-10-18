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
