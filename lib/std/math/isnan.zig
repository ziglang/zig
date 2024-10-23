const std = @import("../std.zig");
const builtin = @import("builtin");
const math = std.math;
const meta = std.meta;
const expect = std.testing.expect;

pub fn isNan(x: anytype) bool {
    return x != x;
}

/// TODO: LLVM is known to miscompile on some architectures to quiet NaN -
///       this is tracked by https://github.com/ziglang/zig/issues/14366
pub fn isSignalNan(x: anytype) bool {
    const T = @TypeOf(x);
    const U = meta.Int(.unsigned, @bitSizeOf(T));
    const quiet_signal_bit_mask = 1 << (math.floatFractionalBits(T) - 1);
    return isNan(x) and (@as(U, @bitCast(x)) & quiet_signal_bit_mask == 0);
}

test isNan {
    inline for ([_]type{ f16, f32, f64, f80, f128, c_longdouble }) |T| {
        try expect(isNan(math.nan(T)));
        try expect(isNan(-math.nan(T)));
        try expect(isNan(math.snan(T)));
        try expect(!isNan(@as(T, 1.0)));
        try expect(!isNan(@as(T, math.inf(T))));
    }
}

test isSignalNan {
    inline for ([_]type{ f16, f32, f64, f80, f128, c_longdouble }) |T| {
        // TODO: Signalling NaN values get converted to quiet NaN values in
        //       some cases where they shouldn't such that this can fail.
        //       See https://github.com/ziglang/zig/issues/14366
        if (!builtin.cpu.arch.isArmOrThumb() and
            !builtin.cpu.arch.isAARCH64() and
            !builtin.cpu.arch.isPowerPC() and
            builtin.zig_backend != .stage2_c)
        {
            try expect(isSignalNan(math.snan(T)));
        }
        try expect(!isSignalNan(math.nan(T)));
        try expect(!isSignalNan(@as(T, 1.0)));
        try expect(!isSignalNan(math.inf(T)));
    }
}
