const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;
const maxInt = std.math.maxInt;

/// Returns whether x is a nan.
pub fn isNan(x: anytype) bool {
    return x != x;
}

/// Returns whether x is a signalling nan.
pub fn isSignalNan(x: anytype) bool {
    // Note: A signalling nan is identical to a standard nan right now but may have a different bit
    // representation in the future when required.
    return isNan(x);
}

test "math.isNan" {
    expect(isNan(math.nan(f16)));
    expect(isNan(math.nan(f32)));
    expect(isNan(math.nan(f64)));
    expect(isNan(math.nan(f128)));
    expect(!isNan(@as(f16, 1.0)));
    expect(!isNan(@as(f32, 1.0)));
    expect(!isNan(@as(f64, 1.0)));
    expect(!isNan(@as(f128, 1.0)));
}
