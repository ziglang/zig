const std = @import("../std.zig");
const math = std.math;
const testing = std.testing;

/// Returns the natural logarithm of x.
///
/// Special Cases:
///  - ln(+inf)  = +inf
///  - ln(0)     = -inf
///  - ln(x)     = nan if x < 0
///  - ln(nan)   = nan
///  TODO remove this in favor of `@log`.
pub fn ln(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    switch (@typeInfo(T)) {
        .ComptimeFloat => {
            return @as(comptime_float, @log(x));
        },
        .Float => return @log(x),
        .ComptimeInt => {
            return @as(comptime_int, @floor(@log(@as(f64, x))));
        },
        .Int => |IntType| switch (IntType.signedness) {
            .signed => @compileError("ln not implemented for signed integers"),
            .unsigned => return @as(T, @floor(@log(@as(f64, x)))),
        },
        else => @compileError("ln not implemented for " ++ @typeName(T)),
    }
}

test "math.ln" {
    try testing.expect(ln(@as(f32, 0.2)) == @log(0.2));
    try testing.expect(ln(@as(f64, 0.2)) == @log(0.2));
}
