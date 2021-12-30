// negv - negate oVerflow
// * @panic, if result can not be represented
// - negvXi4_generic for unoptimized version

// assume -0 == 0 is gracefully handled by the hardware
fn negvXi_generic(comptime ST: type) fn (a: ST) callconv(.C) ST {
    return struct {
        fn f(a: ST) callconv(.C) ST {
            const UT = switch (ST) {
                i32 => u32,
                i64 => u64,
                i128 => u128,
                else => unreachable,
            };
            const N: UT = @bitSizeOf(ST);
            const min: ST = @bitCast(ST, (@as(UT, 1) << (N - 1)));
            if (a == min)
                @panic("compiler_rt negv: overflow");
            return -a;
        }
    }.f;
}
pub const __negvsi2 = negvXi_generic(i32);
pub const __negvdi2 = negvXi_generic(i64);
pub const __negvti2 = negvXi_generic(i128);

test {
    _ = @import("negvsi2_test.zig");
    _ = @import("negvdi2_test.zig");
    _ = @import("negvti2_test.zig");
}
