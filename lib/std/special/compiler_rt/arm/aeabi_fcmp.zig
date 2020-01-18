// Ported from:
//
// https://github.com/llvm/llvm-project/commit/d674d96bc56c0f377879d01c9d8dfdaaa7859cdb/compiler-rt/lib/builtins/arm/aeabi_fcmp.S

const comparesf2 = @import("../comparesf2.zig");

pub fn __aeabi_fcmpeq(a: f32, b: f32) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @boolToInt(@call(.{ .modifier = .always_inline }, comparesf2.__eqsf2, .{ a, b }) == 0);
}

pub fn __aeabi_fcmplt(a: f32, b: f32) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @boolToInt(@call(.{ .modifier = .always_inline }, comparesf2.__ltsf2, .{ a, b }) < 0);
}

pub fn __aeabi_fcmple(a: f32, b: f32) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @boolToInt(@call(.{ .modifier = .always_inline }, comparesf2.__lesf2, .{ a, b }) <= 0);
}

pub fn __aeabi_fcmpge(a: f32, b: f32) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @boolToInt(@call(.{ .modifier = .always_inline }, comparesf2.__gesf2, .{ a, b }) >= 0);
}

pub fn __aeabi_fcmpgt(a: f32, b: f32) callconv(.AAPCS) i32 {
    @setRuntimeSafety(false);
    return @boolToInt(@call(.{ .modifier = .always_inline }, comparesf2.__gtsf2, .{ a, b }) > 0);
}
