const std = @import("std");
const builtin = @import("builtin");

test "issue12891" {
    const f = 10.0;
    var i: usize = 0;
    try std.testing.expect(i < f);
}
test "nan" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const f = comptime std.math.nan(f64);
    var i: usize = 0;
    try std.testing.expect(!(f < i));
}
test "inf" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const f = comptime std.math.inf(f64);
    var i: usize = 0;
    try std.testing.expect(f > i);
}
test "-inf < 0" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const f = comptime -std.math.inf(f64);
    var i: usize = 0;
    try std.testing.expect(f < i);
}
test "inf >= 1" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const f = comptime std.math.inf(f64);
    var i: usize = 1;
    try std.testing.expect(f >= i);
}
test "isNan(nan * 1)" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const nan_times_one = comptime std.math.nan(f64) * 1;
    try std.testing.expect(std.math.isNan(nan_times_one));
}
test "runtime isNan(nan * 1)" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const nan_times_one = std.math.nan(f64) * 1;
    try std.testing.expect(std.math.isNan(nan_times_one));
}
test "isNan(nan * 0)" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const nan_times_zero = comptime std.math.nan(f64) * 0;
    try std.testing.expect(std.math.isNan(nan_times_zero));
    const zero_times_nan = 0 * comptime std.math.nan(f64);
    try std.testing.expect(std.math.isNan(zero_times_nan));
}
test "isNan(inf * 0)" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const inf_times_zero = comptime std.math.inf(f64) * 0;
    try std.testing.expect(std.math.isNan(inf_times_zero));
    const zero_times_inf = 0 * comptime std.math.inf(f64);
    try std.testing.expect(std.math.isNan(zero_times_inf));
}
test "runtime isNan(nan * 0)" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const nan_times_zero = std.math.nan(f64) * 0;
    try std.testing.expect(std.math.isNan(nan_times_zero));
    const zero_times_nan = 0 * std.math.nan(f64);
    try std.testing.expect(std.math.isNan(zero_times_nan));
}
test "runtime isNan(inf * 0)" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const inf_times_zero = std.math.inf(f64) * 0;
    try std.testing.expect(std.math.isNan(inf_times_zero));
    const zero_times_inf = 0 * std.math.inf(f64);
    try std.testing.expect(std.math.isNan(zero_times_inf));
}
