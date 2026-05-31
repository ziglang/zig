const std = @import("std");
const expect = std.testing.expect;

extern fn add(a: u32, b: u32) u32;
extern var foo: u32;

test "C add" {
    const result = add(1, 2);
    try expect(result == 3);
}

test "C extern variable" {
    try expect(foo == 12345);
}
