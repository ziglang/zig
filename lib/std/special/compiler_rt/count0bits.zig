const std = @import("std");
const builtin = @import("builtin");

// clz - count leading zeroes
// - clzXi2_generic for unoptimized little and big endian
// - __clzsi2_thumb1: assume a != 0
// - __clzsi2_arm32: assume a != 0

// ctz - count trailing zeroes
// - ctzXi2_generic for unoptimized little and big endian

// ffs - find first set
// * ffs = (a == 0) => 0, (a != 0) => ctz + 1
// * dont pay for `if (x == 0) return shift;` inside ctz
// - ffsXi2_generic for unoptimized little and big endian

fn clzXi2_generic(comptime T: type) fn (a: T) callconv(.C) i32 {
    return struct {
        fn f(a: T) callconv(.C) i32 {
            @setRuntimeSafety(builtin.is_test);

            var x = switch (@bitSizeOf(T)) {
                32 => @bitCast(u32, a),
                64 => @bitCast(u64, a),
                128 => @bitCast(u128, a),
                else => unreachable,
            };
            var n: T = @bitSizeOf(T);
            // Count first bit set using binary search, from Hacker's Delight
            var y: @TypeOf(x) = 0;
            comptime var shift: u8 = @bitSizeOf(T);
            inline while (shift > 0) {
                shift = shift >> 1;
                y = x >> shift;
                if (y != 0) {
                    n = n - shift;
                    x = y;
                }
            }
            return @intCast(i32, n - @bitCast(T, x));
        }
    }.f;
}

fn __clzsi2_thumb1() callconv(.Naked) void {
    @setRuntimeSafety(false);

    // Similar to the generic version with the last two rounds replaced by a LUT
    asm volatile (
        \\ movs r1, #32
        \\ lsrs r2, r0, #16
        \\ beq 1f
        \\ subs r1, #16
        \\ movs r0, r2
        \\ 1:
        \\ lsrs r2, r0, #8
        \\ beq 1f
        \\ subs r1, #8
        \\ movs r0, r2
        \\ 1:
        \\ lsrs r2, r0, #4
        \\ beq 1f
        \\ subs r1, #4
        \\ movs r0, r2
        \\ 1:
        \\ ldr r3, =LUT
        \\ ldrb r0, [r3, r0]
        \\ subs r0, r1, r0
        \\ bx lr
        \\ .p2align 2
        \\ // Number of bits set in the 0-15 range
        \\ LUT:
        \\ .byte 0,1,2,2,3,3,3,3,4,4,4,4,4,4,4,4
    );

    unreachable;
}

fn __clzsi2_arm32() callconv(.Naked) void {
    @setRuntimeSafety(false);

    asm volatile (
        \\ // Assumption: n != 0
        \\ // r0: n
        \\ // r1: count of leading zeros in n + 1
        \\ // r2: scratch register for shifted r0
        \\ mov r1, #1
        \\
        \\ // Basic block:
        \\ // if ((r0 >> SHIFT) == 0)
        \\ //   r1 += SHIFT;
        \\ // else
        \\ //   r0 >>= SHIFT;
        \\ // for descending powers of two as SHIFT.
        \\ lsrs r2, r0, #16
        \\ movne r0, r2
        \\ addeq r1, #16
        \\
        \\ lsrs r2, r0, #8
        \\ movne r0, r2
        \\ addeq r1, #8
        \\
        \\ lsrs r2, r0, #4
        \\ movne r0, r2
        \\ addeq r1, #4
        \\
        \\ lsrs r2, r0, #2
        \\ movne r0, r2
        \\ addeq r1, #2
        \\
        \\ // The basic block invariants at this point are (r0 >> 2) == 0 and
        \\ // r0 != 0. This means 1 <= r0 <= 3 and 0 <= (r0 >> 1) <= 1.
        \\ //
        \\ // r0 | (r0 >> 1) == 0 | (r0 >> 1) == 1 | -(r0 >> 1) | 1 - (r0 >> 1)f
        \\ // ---+----------------+----------------+------------+--------------
        \\ // 1  | 1              | 0              | 0          | 1
        \\ // 2  | 0              | 1              | -1         | 0
        \\ // 3  | 0              | 1              | -1         | 0
        \\ //
        \\ // The r1's initial value of 1 compensates for the 1 here.
        \\ sub r0, r1, r0, lsr #1
        \\ bx lr
    );

    unreachable;
}

pub const __clzsi2 = impl: {
    switch (builtin.cpu.arch) {
        .arm, .armeb, .thumb, .thumbeb => {
            const use_thumb1 =
                (builtin.cpu.arch.isThumb() or
                std.Target.arm.featureSetHas(builtin.cpu.features, .noarm)) and
                !std.Target.arm.featureSetHas(builtin.cpu.features, .thumb2);

            if (use_thumb1) {
                break :impl __clzsi2_thumb1;
            }
            // From here on we're either targeting Thumb2 or ARM.
            else if (!builtin.cpu.arch.isThumb()) {
                break :impl __clzsi2_arm32;
            }
            // Use the generic implementation otherwise.
            else break :impl clzXi2_generic(i32);
        },
        else => break :impl clzXi2_generic(i32),
    }
};

pub const __clzdi2 = clzXi2_generic(i64);

pub const __clzti2 = clzXi2_generic(i128);

fn ctzXi2_generic(comptime T: type) fn (a: T) callconv(.C) i32 {
    return struct {
        fn f(a: T) callconv(.C) i32 {
            @setRuntimeSafety(builtin.is_test);

            var x = switch (@bitSizeOf(T)) {
                32 => @bitCast(u32, a),
                64 => @bitCast(u64, a),
                128 => @bitCast(u128, a),
                else => unreachable,
            };
            var n: T = 1;
            // Number of trailing zeroes as binary search, from Hacker's Delight
            var mask: @TypeOf(x) = std.math.maxInt(@TypeOf(x));
            comptime var shift = @bitSizeOf(T);
            if (x == 0) return shift;
            inline while (shift > 1) {
                shift = shift >> 1;
                mask = mask >> shift;
                if ((x & mask) == 0) {
                    n = n + shift;
                    x = x >> shift;
                }
            }
            return @intCast(i32, n - @bitCast(T, (x & 1)));
        }
    }.f;
}

pub const __ctzsi2 = ctzXi2_generic(i32);

pub const __ctzdi2 = ctzXi2_generic(i64);

pub const __ctzti2 = ctzXi2_generic(i128);

fn ffsXi2_generic(comptime T: type) fn (a: T) callconv(.C) i32 {
    return struct {
        fn f(a: T) callconv(.C) i32 {
            @setRuntimeSafety(builtin.is_test);

            var x = switch (@bitSizeOf(T)) {
                32 => @bitCast(u32, a),
                64 => @bitCast(u64, a),
                128 => @bitCast(u128, a),
                else => unreachable,
            };
            var n: T = 1;
            // adapted from Number of trailing zeroes (see ctzXi2_generic)
            var mask: @TypeOf(x) = std.math.maxInt(@TypeOf(x));
            comptime var shift = @bitSizeOf(T);
            // In contrast to ctz return 0
            if (x == 0) return 0;
            inline while (shift > 1) {
                shift = shift >> 1;
                mask = mask >> shift;
                if ((x & mask) == 0) {
                    n = n + shift;
                    x = x >> shift;
                }
            }
            // return ctz + 1
            return @intCast(i32, n - @bitCast(T, (x & 1))) + @as(i32, 1);
        }
    }.f;
}

pub const __ffssi2 = ffsXi2_generic(i32);

pub const __ffsdi2 = ffsXi2_generic(i64);

pub const __ffsti2 = ffsXi2_generic(i128);

test {
    _ = @import("clzsi2_test.zig");
    _ = @import("clzdi2_test.zig");
    _ = @import("clzti2_test.zig");

    _ = @import("ctzsi2_test.zig");
    _ = @import("ctzdi2_test.zig");
    _ = @import("ctzti2_test.zig");

    _ = @import("ffssi2_test.zig");
    _ = @import("ffsdi2_test.zig");
    _ = @import("ffsti2_test.zig");
}
