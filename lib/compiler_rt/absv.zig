/// absv - absolute oVerflow
/// * @panic if value can not be represented
pub inline fn absv(comptime ST: type, a: ST) ST {
    const UT = switch (ST) {
        i32 => u32,
        i64 => u64,
        i128 => u128,
        else => unreachable,
    };
    // taken from  Bit Twiddling Hacks
    // compute the integer absolute value (abs) without branching
    var x: ST = a;
    const N: UT = @bitSizeOf(ST);
    const sign: ST = a >> N - 1;
    x +%= sign;
    x ^= sign;
    if (x < 0)
        @panic("compiler_rt absv: overflow");
    return x;
}

test {
    _ = @import("absvsi2_test.zig");
    _ = @import("absvdi2_test.zig");
    _ = @import("absvti2_test.zig");
}
