// absv - absolute oVerflow
// * @panic, if value can not be represented
// - absvXi4_generic for unoptimized version

inline fn absvXi(comptime ST: type, a: ST) ST {
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

pub fn __absvsi2(a: i32) callconv(.C) i32 {
    return absvXi(i32, a);
}

pub fn __absvdi2(a: i64) callconv(.C) i64 {
    return absvXi(i64, a);
}

pub fn __absvti2(a: i128) callconv(.C) i128 {
    return absvXi(i128, a);
}

test {
    _ = @import("absvsi2_test.zig");
    _ = @import("absvdi2_test.zig");
    _ = @import("absvti2_test.zig");
}
