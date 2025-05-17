const std = @import("../std.zig");
const builtin = @import("builtin");
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
    return switch (@typeInfo(T)) {
        .comptime_float, .float => @log2(x),
        .comptime_int => comptime {
            std.debug.assert(x > 0);
            var x_shifted = x;
            // First, calculate floorPowerOfTwo(x)
            var shift_amt = 1;
            while (x_shifted >> (shift_amt << 1) != 0) shift_amt <<= 1;

            // Answer is in the range [shift_amt, 2 * shift_amt - 1]
            // We can find it in O(log(N)) using binary search.
            var result = 0;
            while (shift_amt != 0) : (shift_amt >>= 1) {
                if (x_shifted >> shift_amt != 0) {
                    x_shifted >>= shift_amt;
                    result += shift_amt;
                }
            }
            return result;
        },
        .int => |int_info| math.log2_int(switch (int_info.signedness) {
            .signed => @Type(.{ .int = .{
                .signedness = .unsigned,
                .bits = int_info.bits -| 1,
            } }),
            .unsigned => T,
        }, @intCast(x)),
        else => @compileError("log2 not implemented for " ++ @typeName(T)),
    };
}

test log2 {
    // https://github.com/ziglang/zig/issues/13703
    if (builtin.cpu.arch == .aarch64 and builtin.os.tag == .windows) return error.SkipZigTest;

    try expect(log2(@as(f32, 0.2)) == @log2(0.2));
    try expect(log2(@as(f64, 0.2)) == @log2(0.2));
    comptime {
        try expect(log2(1) == 0);
        try expect(log2(15) == 3);
        try expect(log2(16) == 4);
        try expect(log2(1 << 4073) == 4073);
    }
}
