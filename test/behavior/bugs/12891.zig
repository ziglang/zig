const std = @import("std");
const builtin = @import("builtin");

test "issue12891" {
    const f = 10.0;
    var i: usize = 0;
    try std.testing.expect(i < f);
}
test "nan" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

    const f = comptime std.math.nan(f64);
    var i: usize = 0;
    try std.testing.expect(!(f < i));
}
test "inf" {
    const f = comptime std.math.inf(f64);
    var i: usize = 0;
    try std.testing.expect(f > i);
}
