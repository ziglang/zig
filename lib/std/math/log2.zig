const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns the base-2 logarithm of x.
///
/// Special Cases:
///  - log2(+inf)  = +inf
///  - log2(0)     = -inf
///  - log2(x)     = nan if x < 0
///  - log2(nan)   = nan
pub fn log2(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    switch (@typeInfo(T)) {
        .ComptimeFloat => {
            return @as(comptime_float, @log2(x));
        },
        .Float => return @log2(x),
        .ComptimeInt => comptime {
            var result = 0;
            var x_shifted = x;
            while (b: {
                x_shifted >>= 1;
                break :b x_shifted != 0;
            }) : (result += 1) {}
            return result;
        },
        .Int => |IntType| switch (IntType.signedness) {
            .signed => @compileError("log2 not implemented for signed integers"),
            .unsigned => return math.log2_int(T, x),
        },
        else => @compileError("log2 not implemented for " ++ @typeName(T)),
    }
}

test "log2" {
    try expect(log2(@as(f32, 0.2)) == @log2(0.2));
    try expect(log2(@as(f64, 0.2)) == @log2(0.2));
}
