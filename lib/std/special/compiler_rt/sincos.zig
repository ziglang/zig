pub fn __sincosh(a: f16, r_sin: *f16, r_cos: *f16) callconv(.C) void {
    r_sin.* = @sin(a);
    r_cos.* = @cos(a);
}

pub fn sincosf(a: f32, r_sin: *f32, r_cos: *f32) callconv(.C) void {
    r_sin.* = @sin(a);
    r_cos.* = @cos(a);
}

pub fn sincos(a: f64, r_sin: *f64, r_cos: *f64) callconv(.C) void {
    r_sin.* = @sin(a);
    r_cos.* = @cos(a);
}

pub fn __sincosx(a: f80, r_sin: *f80, r_cos: *f80) callconv(.C) void {
    r_sin.* = @sin(a);
    r_cos.* = @cos(a);
}

pub fn sincosq(a: f128, r_sin: *f128, r_cos: *f128) callconv(.C) void {
    r_sin.* = @sin(a);
    r_cos.* = @cos(a);
}
