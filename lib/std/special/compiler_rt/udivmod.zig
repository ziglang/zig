const builtin = @import("builtin");
const is_test = builtin.is_test;

const low = switch (builtin.endian) {
    .Big => 1,
    .Little => 0,
};
const high = 1 - low;

pub fn udivmod(comptime DoubleInt: type, a: DoubleInt, b: DoubleInt, maybe_rem: ?*DoubleInt) DoubleInt {
    @setRuntimeSafety(is_test);

    const SingleInt = @import("std").meta.Int(false, @divExact(DoubleInt.bit_count, 2));
    const SignedDoubleInt = @import("std").meta.Int(true, DoubleInt.bit_count);
    const Log2SingleInt = @import("std").math.Log2Int(SingleInt);

    const n = @ptrCast(*const [2]SingleInt, &a).*; // TODO issue #421
    const d = @ptrCast(*const [2]SingleInt, &b).*; // TODO issue #421
    var q: [2]SingleInt = undefined;
    var r: [2]SingleInt = undefined;
    var sr: c_uint = undefined;
    // special cases, X is unknown, K != 0
    if (n[high] == 0) {
        if (d[high] == 0) {
            // 0 X
            // ---
            // 0 X
            if (maybe_rem) |rem| {
                rem.* = n[low] % d[low];
            }
            return n[low] / d[low];
        }
        // 0 X
        // ---
        // K X
        if (maybe_rem) |rem| {
            rem.* = n[low];
        }
        return 0;
    }
    // n[high] != 0
    if (d[low] == 0) {
        if (d[high] == 0) {
            // K X
            // ---
            // 0 0
            if (maybe_rem) |rem| {
                rem.* = n[high] % d[low];
            }
            return n[high] / d[low];
        }
        // d[high] != 0
        if (n[low] == 0) {
            // K 0
            // ---
            // K 0
            if (maybe_rem) |rem| {
                r[high] = n[high] % d[high];
                r[low] = 0;
                rem.* = @ptrCast(*align(@alignOf(SingleInt)) DoubleInt, &r[0]).*; // TODO issue #421
            }
            return n[high] / d[high];
        }
        // K K
        // ---
        // K 0
        if ((d[high] & (d[high] - 1)) == 0) {
            // d is a power of 2
            if (maybe_rem) |rem| {
                r[low] = n[low];
                r[high] = n[high] & (d[high] - 1);
                rem.* = @ptrCast(*align(@alignOf(SingleInt)) DoubleInt, &r[0]).*; // TODO issue #421
            }
            return n[high] >> @intCast(Log2SingleInt, @ctz(SingleInt, d[high]));
        }
        // K K
        // ---
        // K 0
        sr = @bitCast(c_uint, @as(c_int, @clz(SingleInt, d[high])) - @as(c_int, @clz(SingleInt, n[high])));
        // 0 <= sr <= SingleInt.bit_count - 2 or sr large
        if (sr > SingleInt.bit_count - 2) {
            if (maybe_rem) |rem| {
                rem.* = a;
            }
            return 0;
        }
        sr += 1;
        // 1 <= sr <= SingleInt.bit_count - 1
        // q.all = a << (DoubleInt.bit_count - sr);
        q[low] = 0;
        q[high] = n[low] << @intCast(Log2SingleInt, SingleInt.bit_count - sr);
        // r.all = a >> sr;
        r[high] = n[high] >> @intCast(Log2SingleInt, sr);
        r[low] = (n[high] << @intCast(Log2SingleInt, SingleInt.bit_count - sr)) | (n[low] >> @intCast(Log2SingleInt, sr));
    } else {
        // d[low] != 0
        if (d[high] == 0) {
            // K X
            // ---
            // 0 K
            if ((d[low] & (d[low] - 1)) == 0) {
                // d is a power of 2
                if (maybe_rem) |rem| {
                    rem.* = n[low] & (d[low] - 1);
                }
                if (d[low] == 1) {
                    return a;
                }
                sr = @ctz(SingleInt, d[low]);
                q[high] = n[high] >> @intCast(Log2SingleInt, sr);
                q[low] = (n[high] << @intCast(Log2SingleInt, SingleInt.bit_count - sr)) | (n[low] >> @intCast(Log2SingleInt, sr));
                return @ptrCast(*align(@alignOf(SingleInt)) DoubleInt, &q[0]).*; // TODO issue #421
            }
            // K X
            // ---
            // 0 K
            sr = 1 + SingleInt.bit_count + @as(c_uint, @clz(SingleInt, d[low])) - @as(c_uint, @clz(SingleInt, n[high]));
            // 2 <= sr <= DoubleInt.bit_count - 1
            // q.all = a << (DoubleInt.bit_count - sr);
            // r.all = a >> sr;
            if (sr == SingleInt.bit_count) {
                q[low] = 0;
                q[high] = n[low];
                r[high] = 0;
                r[low] = n[high];
            } else if (sr < SingleInt.bit_count) {
                // 2 <= sr <= SingleInt.bit_count - 1
                q[low] = 0;
                q[high] = n[low] << @intCast(Log2SingleInt, SingleInt.bit_count - sr);
                r[high] = n[high] >> @intCast(Log2SingleInt, sr);
                r[low] = (n[high] << @intCast(Log2SingleInt, SingleInt.bit_count - sr)) | (n[low] >> @intCast(Log2SingleInt, sr));
            } else {
                // SingleInt.bit_count + 1 <= sr <= DoubleInt.bit_count - 1
                q[low] = n[low] << @intCast(Log2SingleInt, DoubleInt.bit_count - sr);
                q[high] = (n[high] << @intCast(Log2SingleInt, DoubleInt.bit_count - sr)) | (n[low] >> @intCast(Log2SingleInt, sr - SingleInt.bit_count));
                r[high] = 0;
                r[low] = n[high] >> @intCast(Log2SingleInt, sr - SingleInt.bit_count);
            }
        } else {
            // K X
            // ---
            // K K
            sr = @bitCast(c_uint, @as(c_int, @clz(SingleInt, d[high])) - @as(c_int, @clz(SingleInt, n[high])));
            // 0 <= sr <= SingleInt.bit_count - 1 or sr large
            if (sr > SingleInt.bit_count - 1) {
                if (maybe_rem) |rem| {
                    rem.* = a;
                }
                return 0;
            }
            sr += 1;
            // 1 <= sr <= SingleInt.bit_count
            // q.all = a << (DoubleInt.bit_count - sr);
            // r.all = a >> sr;
            q[low] = 0;
            if (sr == SingleInt.bit_count) {
                q[high] = n[low];
                r[high] = 0;
                r[low] = n[high];
            } else {
                r[high] = n[high] >> @intCast(Log2SingleInt, sr);
                r[low] = (n[high] << @intCast(Log2SingleInt, SingleInt.bit_count - sr)) | (n[low] >> @intCast(Log2SingleInt, sr));
                q[high] = n[low] << @intCast(Log2SingleInt, SingleInt.bit_count - sr);
            }
        }
    }
    // Not a special case
    // q and r are initialized with:
    // q.all = a << (DoubleInt.bit_count - sr);
    // r.all = a >> sr;
    // 1 <= sr <= DoubleInt.bit_count - 1
    var carry: u32 = 0;
    var r_all: DoubleInt = undefined;
    while (sr > 0) : (sr -= 1) {
        // r:q = ((r:q)  << 1) | carry
        r[high] = (r[high] << 1) | (r[low] >> (SingleInt.bit_count - 1));
        r[low] = (r[low] << 1) | (q[high] >> (SingleInt.bit_count - 1));
        q[high] = (q[high] << 1) | (q[low] >> (SingleInt.bit_count - 1));
        q[low] = (q[low] << 1) | carry;
        // carry = 0;
        // if (r.all >= b)
        // {
        //     r.all -= b;
        //      carry = 1;
        // }
        r_all = @ptrCast(*align(@alignOf(SingleInt)) DoubleInt, &r[0]).*; // TODO issue #421
        const s: SignedDoubleInt = @bitCast(SignedDoubleInt, b -% r_all -% 1) >> (DoubleInt.bit_count - 1);
        carry = @intCast(u32, s & 1);
        r_all -= b & @bitCast(DoubleInt, s);
        r = @ptrCast(*[2]SingleInt, &r_all).*; // TODO issue #421
    }
    const q_all = ((@ptrCast(*align(@alignOf(SingleInt)) DoubleInt, &q[0]).*) << 1) | carry; // TODO issue #421
    if (maybe_rem) |rem| {
        rem.* = r_all;
    }
    return q_all;
}
