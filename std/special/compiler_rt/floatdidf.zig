const builtin = @import("builtin");
const std = @import("std");

const twop52: f64 = 0x1.0p52;
const twop32: f64 = 0x1.0p32;

pub extern fn __floatdidf(a: i64) f64 {
    @setRuntimeSafety(builtin.is_test);

    if (a == 0) return 0;

    var low = @bitCast(i64, twop52);
    const high = @intToFloat(f64, @truncate(i32, a >> 32)) * twop32;

    low |= @bitCast(i64, a & 0xFFFFFFFF);

    return (high - twop52) + @bitCast(f64, low);
}

test "import floatdidf" {
    _ = @import("floatdidf_test.zig");
}
