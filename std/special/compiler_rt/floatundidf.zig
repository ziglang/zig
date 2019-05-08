const builtin = @import("builtin");
const std = @import("std");

const twop52: f64 = 0x1.0p52;
const twop84: f64 = 0x1.0p84;
const twop84_plus_twop52: f64 = 0x1.00000001p84;

pub extern fn __floatundidf(a: u64) f64 {
    @setRuntimeSafety(builtin.is_test);

    if (a == 0) return 0;

    var high = @bitCast(u64, twop84);
    var low = @bitCast(u64, twop52);

    high |= a >> 32;
    low |= a & 0xFFFFFFFF;

    return (@bitCast(f64, high) - twop84_plus_twop52) + @bitCast(f64, low);
}

test "import floatundidf" {
    _ = @import("floatundidf_test.zig");
}
