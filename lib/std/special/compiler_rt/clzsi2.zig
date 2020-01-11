// Ported from:
//
// https://github.com/llvm-mirror/compiler-rt/blob/f0745e8476f069296a7c71accedd061dce4cdf79/lib/builtins/clzsi2.c
// https://github.com/llvm-mirror/compiler-rt/blob/f0745e8476f069296a7c71accedd061dce4cdf79/lib/builtins/arm/clzsi2.S
const builtin = @import("builtin");

// Precondition: a != 0
fn __clzsi2_generic(a: i32) callconv(.C) i32 {
    @setRuntimeSafety(builtin.is_test);

    var x = @bitCast(u32, a);
    var n: i32 = 32;

    // Count first bit set using binary search, from Hacker's Delight
    var y: u32 = 0;
    inline for ([_]i32{ 16, 8, 4, 2, 1 }) |shift| {
        y = x >> shift;
        if (y != 0) {
            n = n - shift;
            x = y;
        }
    }

    return n - @bitCast(i32, x);
}

fn __clzsi2_arm_clz(a: i32) callconv(.Naked) noreturn {
    asm volatile (
        \\ clz r0,r0
        \\ bx lr
    );
    unreachable;
}

fn __clzsi2_arm32(a: i32) callconv(.Naked) noreturn {
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

const can_use_arm_clz = switch (builtin.arch) {
    .arm, .armeb => |sub_arch| switch (sub_arch) {
        .v4t => false,
        .v6m => false,
        else => true,
    },
    .thumb, .thumbeb => |sub_arch| switch (sub_arch) {
        .v6,
        .v6k,
        .v5,
        .v5te,
        .v4t,
        => false,
        else => true,
    },
    else => false,
};

const is_arm32_no_thumb = switch (builtin.arch) {
    builtin.Arch.arm,
    builtin.Arch.armeb,
    => true,
    else => false,
};

pub const __clzsi2 = blk: {
    if (comptime can_use_arm_clz) {
        break :blk __clzsi2_arm_clz;
    } else if (comptime is_arm32_no_thumb) {
        break :blk __clzsi2_arm32;
    } else {
        break :blk __clzsi2_generic;
    }
};

test "test clzsi2" {
    _ = @import("clzsi2_test.zig");
}
