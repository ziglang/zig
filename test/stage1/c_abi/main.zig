const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;

extern fn run_c_tests() void;

export fn zig_panic() noreturn {
    @panic("zig_panic called from C");
}

test "C importing Zig ABI Tests" {
    run_c_tests();
}

extern fn c_u8(u8) void;
extern fn c_u16(u16) void;
extern fn c_u32(u32) void;
extern fn c_u64(u64) void;
extern fn c_i8(i8) void;
extern fn c_i16(i16) void;
extern fn c_i32(i32) void;
extern fn c_i64(i64) void;

test "C ABI integers" {
    c_u8(0xff);
    c_u16(0xfffe);
    c_u32(0xfffffffd);
    c_u64(0xfffffffffffffffc);

    c_i8(-1);
    c_i16(-2);
    c_i32(-3);
    c_i64(-4);
}

export fn zig_u8(x: u8) void {
    assertOrPanic(x == 0xff);
}
export fn zig_u16(x: u16) void {
    assertOrPanic(x == 0xfffe);
}
export fn zig_u32(x: u32) void {
    assertOrPanic(x == 0xfffffffd);
}
export fn zig_u64(x: u64) void {
    assertOrPanic(x == 0xfffffffffffffffc);
}
export fn zig_i8(x: i8) void {
    assertOrPanic(x == -1);
}
export fn zig_i16(x: i16) void {
    assertOrPanic(x == -2);
}
export fn zig_i32(x: i32) void {
    assertOrPanic(x == -3);
}
export fn zig_i64(x: i64) void {
    assertOrPanic(x == -4);
}
