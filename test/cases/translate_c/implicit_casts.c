#include <stdbool.h>

void fn_int(int x);
void fn_f32(float x);
void fn_f64(double x);
void fn_char(char x);
void fn_bool(bool x);
void fn_ptr(void *x);

void call() {
    fn_int(3.0f);
    fn_int(3.0);
    fn_int('ABCD');
    fn_f32(3);
    fn_f64(3);
    fn_char('3');
    fn_char('\x1');
    fn_char(0);
    fn_f32(3.0f);
    fn_f64(3.0);
    fn_bool(123);
    fn_bool(0);
    fn_bool(&fn_int);
    fn_int((int)&fn_int);
    fn_ptr((void *)42);
}

// translate-c
// c_frontends=clang
//
// pub extern fn fn_int(x: c_int) void;
// pub extern fn fn_f32(x: f32) void;
// pub extern fn fn_f64(x: f64) void;
// pub extern fn fn_char(x: u8) void;
// pub extern fn fn_bool(x: bool) void;
// pub extern fn fn_ptr(x: ?*anyopaque) void;
// pub export fn call() void {
//     fn_int(@as(c_int, @intFromFloat(3.0)));
//     fn_int(@as(c_int, @intFromFloat(3.0)));
//     fn_int(@as(c_int, 1094861636));
//     fn_f32(@as(f32, @floatFromInt(@as(c_int, 3))));
//     fn_f64(@as(f64, @floatFromInt(@as(c_int, 3))));
//     fn_char(@as(u8, @bitCast(@as(i8, @truncate(@as(c_int, '3'))))));
//     fn_char(@as(u8, @bitCast(@as(i8, @truncate(@as(c_int, '\x01'))))));
//     fn_char(@as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))));
//     fn_f32(3.0);
//     fn_f64(3.0);
//     fn_bool(@as(c_int, 123) != 0);
//     fn_bool(@as(c_int, 0) != 0);
//     fn_bool(@intFromPtr(&fn_int) != 0);
//     fn_int(@as(c_int, @bitCast(@as(c_uint, @truncate(@intFromPtr(&fn_int))))));
//     fn_ptr(@as(?*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, @as(c_int, 42)))))));
// }
