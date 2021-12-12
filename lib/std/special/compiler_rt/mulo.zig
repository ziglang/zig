const builtin = @import("builtin");

// mulo - multiplication overflow
// - muloXi4_generic for unoptimized version

// return a*b.
// return if a*b overflows => 1 else => 0
// see https://stackoverflow.com/a/26320664 for possible implementations

fn muloXi4_generic(comptime ST: type) fn (a: ST, b: ST, overflow: *c_int) callconv(.C) ST {
    return struct {
        fn f(a: ST, b: ST, overflow: *c_int) callconv(.C) ST {
            @setRuntimeSafety(builtin.is_test);
            const BSIZE = @bitSizeOf(ST);
            comptime var UT = switch (ST) {
                i32 => u32,
                i64 => u64,
                i128 => u128,
                else => unreachable,
            };
            const min = @bitCast(ST, @as(UT, 1 << (BSIZE - 1)));
            const max = ~min;
            overflow.* = 0;
            const result = a *% b;

            // edge cases
            if (a == min) {
                if (b != 0 and b != 1) overflow.* = 1;
                return result;
            }
            if (b == min) {
                if (a != 0 and a != 1) overflow.* = 1;
                return result;
            }

            // take sign of x sx
            const sa = a >> (BSIZE - 1);
            const sb = b >> (BSIZE - 1);
            // take absolute value of a and b via
            // abs(x) = (x^sx)) - sx
            const abs_a = (a ^ sa) -% sa;
            const abs_b = (b ^ sb) -% sb;

            // unitary magnitude, cannot have overflow
            if (abs_a < 2 or abs_b < 2) return result;

            // compare the signs of operands
            if ((a ^ b) >> (BSIZE - 1) != 0) {
                if (abs_a > @divTrunc(max, abs_b)) overflow.* = 1;
            } else {
                if (abs_a > @divTrunc(min, -abs_b)) overflow.* = 1;
            }

            return result;
        }
    }.f;
}

pub const __mulosi4 = muloXi4_generic(i32);

pub const __mulodi4 = muloXi4_generic(i64);

pub const __muloti4 = muloXi4_generic(i128);

test {
    _ = @import("mulosi4_test.zig");
    _ = @import("mulodi4_test.zig");
    _ = @import("muloti4_test.zig");
}
