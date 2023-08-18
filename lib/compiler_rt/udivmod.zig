const std = @import("std");
const builtin = @import("builtin");
const is_test = builtin.is_test;
const Log2Int = std.math.Log2Int;
const HalveInt = @import("common.zig").HalveInt;

const lo = switch (builtin.cpu.arch.endian()) {
    .Big => 1,
    .Little => 0,
};
const hi = 1 - lo;

// Let _u1 and _u0 be the high and low limbs of U respectively.
// Returns U / v_ and sets r = U % v_.
fn divwide_generic(comptime T: type, _u1: T, _u0: T, v_: T, r: *T) T {
    const HalfT = HalveInt(T, false).HalfT;
    @setRuntimeSafety(is_test);
    var v = v_;

    const b = @as(T, 1) << (@bitSizeOf(T) / 2);
    var un64: T = undefined;
    var un10: T = undefined;

    const s = @as(Log2Int(T), @intCast(@clz(v)));
    if (s > 0) {
        // Normalize divisor
        v <<= s;
        un64 = (_u1 << s) | (_u0 >> @as(Log2Int(T), @intCast((@bitSizeOf(T) - @as(T, @intCast(s))))));
        un10 = _u0 << s;
    } else {
        // Avoid undefined behavior of (u0 >> @bitSizeOf(T))
        un64 = _u1;
        un10 = _u0;
    }

    // Break divisor up into two 32-bit digits
    const vn1 = v >> (@bitSizeOf(T) / 2);
    const vn0 = v & std.math.maxInt(HalfT);

    // Break right half of dividend into two digits
    const un1 = un10 >> (@bitSizeOf(T) / 2);
    const un0 = un10 & std.math.maxInt(HalfT);

    // Compute the first quotient digit, q1
    var q1 = un64 / vn1;
    var rhat = un64 -% q1 *% vn1;

    // q1 has at most error 2. No more than 2 iterations
    while (q1 >= b or q1 * vn0 > b * rhat + un1) {
        q1 -= 1;
        rhat += vn1;
        if (rhat >= b) break;
    }

    var un21 = un64 *% b +% un1 -% q1 *% v;

    // Compute the second quotient digit
    var q0 = un21 / vn1;
    rhat = un21 -% q0 *% vn1;

    // q0 has at most error 2. No more than 2 iterations.
    while (q0 >= b or q0 * vn0 > b * rhat + un0) {
        q0 -= 1;
        rhat += vn1;
        if (rhat >= b) break;
    }

    r.* = (un21 *% b +% un0 -% q0 *% v) >> s;
    return q1 *% b +% q0;
}

fn divwide(comptime T: type, _u1: T, _u0: T, v: T, r: *T) T {
    @setRuntimeSafety(is_test);
    if (T == u64 and builtin.target.cpu.arch == .x86_64 and builtin.target.os.tag != .windows) {
        var rem: T = undefined;
        const quo = asm (
            \\divq %[v]
            : [_] "={rax}" (-> T),
              [_] "={rdx}" (rem),
            : [v] "r" (v),
              [_] "{rax}" (_u0),
              [_] "{rdx}" (_u1),
        );
        r.* = rem;
        return quo;
    } else {
        return divwide_generic(T, _u1, _u0, v, r);
    }
}

// Returns a_ / b_ and sets maybe_rem = a_ % b.
pub fn udivmod(comptime T: type, a_: T, b_: T, maybe_rem: ?*T) T {
    @setRuntimeSafety(is_test);
    const HalfT = HalveInt(T, false).HalfT;
    const SignedT = std.meta.Int(.signed, @bitSizeOf(T));

    if (b_ > a_) {
        if (maybe_rem) |rem| {
            rem.* = a_;
        }
        return 0;
    }

    var a = @as([2]HalfT, @bitCast(a_));
    var b = @as([2]HalfT, @bitCast(b_));
    var q: [2]HalfT = undefined;
    var r: [2]HalfT = undefined;

    // When the divisor fits in 64 bits, we can use an optimized path
    if (b[hi] == 0) {
        r[hi] = 0;
        if (a[hi] < b[lo]) {
            // The result fits in 64 bits
            q[hi] = 0;
            q[lo] = divwide(HalfT, a[hi], a[lo], b[lo], &r[lo]);
        } else {
            // First, divide with the high part to get the remainder. After that a_hi < b_lo.
            q[hi] = a[hi] / b[lo];
            q[lo] = divwide(HalfT, a[hi] % b[lo], a[lo], b[lo], &r[lo]);
        }
        if (maybe_rem) |rem| {
            rem.* = @as(T, @bitCast(r));
        }
        return @as(T, @bitCast(q));
    }

    // 0 <= shift <= 63
    var shift: Log2Int(T) = @clz(b[hi]) - @clz(a[hi]);
    var af = @as(T, @bitCast(a));
    var bf = @as(T, @bitCast(b)) << shift;
    q = @as([2]HalfT, @bitCast(@as(T, 0)));

    for (0..shift + 1) |_| {
        q[lo] <<= 1;
        // Branchless version of:
        // if (af >= bf) {
        //     af -= bf;
        //     q[lo] |= 1;
        // }
        const s = @as(SignedT, @bitCast(bf -% af -% 1)) >> (@bitSizeOf(T) - 1);
        q[lo] |= @as(HalfT, @intCast(s & 1));
        af -= bf & @as(T, @bitCast(s));
        bf >>= 1;
    }
    if (maybe_rem) |rem| {
        rem.* = @as(T, @bitCast(af));
    }
    return @as(T, @bitCast(q));
}
