const sin = @import("sin.zig");
const cos = @import("cos.zig");

pub fn __sincosh(a: f16, r_sin: *f16, r_cos: *f16) callconv(.C) void {
    r_sin.* = sin.__sinh(a);
    r_cos.* = cos.__cosh(a);
}

pub fn sincosf(a: f32, r_sin: *f32, r_cos: *f32) callconv(.C) void {
    r_sin.* = sin.sinf(a);
    r_cos.* = cos.cosf(a);
}

pub fn sincos(a: f64, r_sin: *f64, r_cos: *f64) callconv(.C) void {
    r_sin.* = sin.sin(a);
    r_cos.* = cos.cos(a);
}

pub fn __sincosx(a: f80, r_sin: *f80, r_cos: *f80) callconv(.C) void {
    r_sin.* = sin.__sinx(a);
    r_cos.* = cos.__cosx(a);
}

pub fn sincosq(a: f128, r_sin: *f128, r_cos: *f128) callconv(.C) void {
    r_sin.* = sin.sinq(a);
    r_cos.* = cos.cosq(a);
}
