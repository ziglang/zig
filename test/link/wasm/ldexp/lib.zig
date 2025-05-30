// Test that LLVM's exp2 optimization requiring ldexp symbols works correctly.
// In Release modes, LLVM's LibCallSimplifier converts exp2 calls to ldexp
// when the input is an integer converted to float.
// See https://github.com/ziglang/zig/issues/23358

export fn use_double(f: i32) f64 {
    return @exp2(@as(f64, @floatFromInt(f)));
}

export fn use_float(f: i32) f32 {
    return @exp2(@as(f32, @floatFromInt(f)));
}

export fn use_long(f: i32) f128 {
    return @exp2(@as(f128, @floatFromInt(f)));
}
