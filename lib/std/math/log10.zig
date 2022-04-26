const std = @import("../std.zig");
const math = std.math;
const testing = std.testing;
const maxInt = std.math.maxInt;

/// Returns the base-10 logarithm of x.
///
/// Special Cases:
///  - log10(+inf)  = +inf
///  - log10(0)     = -inf
///  - log10(x)     = nan if x < 0
///  - log10(nan)   = nan
pub fn log10(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    switch (@typeInfo(T)) {
        .ComptimeFloat => {
            return @as(comptime_float, @log10(x));
        },
        .Float => return @log10(x),
        .ComptimeInt => {
            return @as(comptime_int, @floor(@log10(@as(f64, x))));
        },
        .Int => |IntType| switch (IntType.signedness) {
            .signed => @compileError("log10 not implemented for signed integers"),
            .unsigned => return @floatToInt(T, @floor(@log10(@intToFloat(f64, x)))),
        },
        else => @compileError("log10 not implemented for " ++ @typeName(T)),
    }
}
