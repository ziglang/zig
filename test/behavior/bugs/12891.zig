const std = @import("std");
const builtin = @import("builtin");

test "issue12891" {
    const f = 10.0;
    var i: usize = 0;
    try std.testing.expect(i < f);
}
test "nan" {
    if (builtin.zig_backend == .stage1) return error.SkipZigTest; // TODO

    const f = comptime std.math.nan(f64);
    var i: usize = 0;
    try std.testing.expect(!(f < i));
}
test "inf" {
    const f = comptime std.math.inf(f64);
    var i: usize = 0;
    try std.testing.expect(f > i);
}
test "-inf < 0" {
    const f = comptime -std.math.inf(f64);
    var i: usize = 0;
    try std.testing.expect(f < i);
}
test "inf >= 1" {
    const f = comptime std.math.inf(f64);
    var i: usize = 1;
    try std.testing.expect(f >= i);
}
test "isNan(nan * 0)" {
    const nan_times_zero = comptime std.math.nan(f64) * 0;
    try std.testing.expect(std.math.isNan(nan_times_zero));
}
test "isNan(inf * 0)" {
    const inf_times_zero = comptime std.math.inf(f64) * 0;
    try std.testing.expect(std.math.isNan(inf_times_zero));
}
test "isNan(nan * 1)" {
    const nan_times_one = comptime std.math.nan(f64) * 1;
    try std.testing.expect(std.math.isNan(nan_times_one));
}
