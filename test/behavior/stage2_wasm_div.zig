const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "wasm integer division" {
    // This test is copied from int_div.zig, with additional test cases for @divFloor on floats.
    // TODO: Remove this test once the division tests in math.zig and int_div.zig pass with the
    // stage2 wasm backend.
    if (builtin.zig_backend != .stage2_wasm) return error.SkipZigTest;

    try testDivision();
    try comptime testDivision();
}
fn testDivision() !void {
    try expect(div(u32, 13, 3) == 4);
    try expect(div(u64, 13, 3) == 4);
    try expect(div(u8, 13, 3) == 4);

    try expect(divFloor(i8, 5, 3) == 1);
    try expect(divFloor(i16, -5, 3) == -2);
    try expect(divFloor(i64, -0x80000000, -2) == 0x40000000);
    try expect(divFloor(i32, 0, -0x80000000) == 0);
    try expect(divFloor(i64, -0x40000001, 0x40000000) == -2);
    try expect(divFloor(i32, -0x80000000, 1) == -0x80000000);
    try expect(divFloor(i32, 10, 12) == 0);
    try expect(divFloor(i32, -14, 12) == -2);
    try expect(divFloor(i32, -2, 12) == -1);
    try expect(divFloor(f32, 56.0, 9.0) == 6.0);
    try expect(divFloor(f32, 1053.0, -41.0) == -26.0);
    try expect(divFloor(f16, -43.0, 12.0) == -4.0);
    try expect(divFloor(f64, -90.0, -9.0) == 10.0);

    try expect(mod(u32, 10, 12) == 10);
    try expect(mod(i32, 10, 12) == 10);
    try expect(mod(i64, -14, 12) == 10);
    try expect(mod(i16, -2, 12) == 10);
    try expect(mod(i8, -2, 12) == 10);

    try expect(rem(i32, 10, 12) == 10);
    try expect(rem(i32, -14, 12) == -2);
    try expect(rem(i32, -2, 12) == -2);
}
fn div(comptime T: type, a: T, b: T) T {
    return a / b;
}
fn divFloor(comptime T: type, a: T, b: T) T {
    return @divFloor(a, b);
}
fn mod(comptime T: type, a: T, b: T) T {
    return @mod(a, b);
}
fn rem(comptime T: type, a: T, b: T) T {
    return @rem(a, b);
}
