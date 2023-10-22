const std = @import("std");
const expect = std.testing.expect;

/// Returns a * FLT_RADIX ^ exp.
///
/// Zig only supports binary base IEEE-754 floats. Hence FLT_RADIX=2, and this is an alias for ldexp.
pub const scalbn = @import("ldexp.zig").ldexp;

test "math.scalbn" {
    // Verify we are using base 2.
    try expect(scalbn(@as(f16, 1.5), 4) == 24.0);
    try expect(scalbn(@as(f32, 1.5), 4) == 24.0);
    try expect(scalbn(@as(f64, 1.5), 4) == 24.0);
    try expect(scalbn(@as(f128, 1.5), 4) == 24.0);
}
