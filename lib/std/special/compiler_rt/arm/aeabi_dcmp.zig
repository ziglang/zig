// Ported from:
//
// https://github.com/llvm/llvm-project/commit/d674d96bc56c0f377879d01c9d8dfdaaa7859cdb/compiler-rt/lib/builtins/arm/aeabi_dcmp.S

const comparedf2 = @import("../comparedf2.zig");

pub fn __aeabi_dcmpeq(a: f64, b: f64) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @boolToInt(@call(.{ .modifier = .always_inline }, comparedf2.__eqdf2, .{ a, b }) == 0);
}

pub fn __aeabi_dcmplt(a: f64, b: f64) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @boolToInt(@call(.{ .modifier = .always_inline }, comparedf2.__ltdf2, .{ a, b }) < 0);
}

pub fn __aeabi_dcmple(a: f64, b: f64) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @boolToInt(@call(.{ .modifier = .always_inline }, comparedf2.__ledf2, .{ a, b }) <= 0);
}

pub fn __aeabi_dcmpge(a: f64, b: f64) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @boolToInt(@call(.{ .modifier = .always_inline }, comparedf2.__gedf2, .{ a, b }) >= 0);
}

pub fn __aeabi_dcmpgt(a: f64, b: f64) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @boolToInt(@call(.{ .modifier = .always_inline }, comparedf2.__gtdf2, .{ a, b }) > 0);
}
