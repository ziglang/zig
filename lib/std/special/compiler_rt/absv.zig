// absv - absolute oVerflow
// * @panic, if value can not be represented
// - absvXi4_generic for unoptimized version

fn absvXi_generic(comptime ST: type) fn (a: ST) callconv(.C) ST {
    return struct {
        fn f(a: ST) callconv(.C) ST {
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
    }.f;
}
pub const __absvsi2 = absvXi_generic(i32);
pub const __absvdi2 = absvXi_generic(i64);
pub const __absvti2 = absvXi_generic(i128);

test {
    _ = @import("absvsi2_test.zig");
    _ = @import("absvdi2_test.zig");
    _ = @import("absvti2_test.zig");
}
