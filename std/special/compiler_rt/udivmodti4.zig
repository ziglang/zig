const builtin = @import("builtin");
const is_test = builtin.is_test;

const low = if (builtin.is_big_endian) 1 else 0;
const high = 1 - low;

export fn __udivmodti4(a: u128, b: u128, maybe_rem: ?&u128) -> u128 {
    @setDebugSafety(this, is_test);

    const n_udword_bits = u64.bit_count;
    const n_utword_bits = u128.bit_count;
    const n = *@ptrCast(&[2]u64, &a); // TODO issue #421
    const d = *@ptrCast(&[2]u64, &b); // TODO issue #421
    var q: [2]u64 = undefined;
    var r: [2]u64 = undefined;
    var sr: c_uint = undefined;
    // special cases, X is unknown, K != 0
    if (n[high] == 0) {
        if (d[high] == 0) {
            // 0 X
            // ---
            // 0 X
            if (maybe_rem) |rem| {
                *rem = n[low] % d[low];
            }
            return n[low] / d[low];
        }
        // 0 X
        // ---
        // K X
        if (maybe_rem) |rem| {
            *rem = n[low];
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
                *rem = n[high] % d[low];
            }
            return n[high] / d[low];
        }
        // d[high] != 0 */
        if (n[low] == 0) {
            // K 0
            // ---
            // K 0
            if (maybe_rem) |rem| {
                r[high] = n[high] % d[high];
                r[low] = 0;
                *rem = *@ptrCast(&u128, &r[0]); // TODO issue #421
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
                *rem = *@ptrCast(&u128, &r[0]); // TODO issue #421
            }
            return n[high] >> @ctz(d[high]);
        }
        // K K
        // ---
        // K 0
        sr = @bitCast(c_uint, c_int(@clz(d[high])) - c_int(@clz(n[high])));
        // 0 <= sr <= n_udword_bits - 2 or sr large
        if (sr > n_udword_bits - 2) {
           if (maybe_rem) |rem| {
                *rem = a;
           }
           return 0;
        }
        sr += 1;
        // 1 <= sr <= n_udword_bits - 1
        // q.all = a << (n_utword_bits - sr);
        q[low] = 0;
        q[high] = n[low] << (n_udword_bits - sr);
        // r.all = a >> sr;
        r[high] = n[high] >> sr;
        r[low] = (n[high] << (n_udword_bits - sr)) | (n[low] >> sr);
    } else {
        // d[low] != 0
        if (d[high] == 0) {
            // K X
            // ---
            // 0 K
            if ((d[low] & (d[low] - 1)) == 0) {
                // if d is a power of 2
                if (maybe_rem) |rem| {
                    *rem = n[low] & (d[low] - 1);
                }
                if (d[low] == 1)
                    return a;
                sr = @ctz(d[low]);
                q[high] = n[high] >> sr;
                q[low] = (n[high] << (n_udword_bits - sr)) | (n[low] >> sr);
                return *@ptrCast(&u128, &q[0]); // TODO issue #421
            }
            // K X
            // ---
            // 0 K
            sr = 1 + n_udword_bits + c_uint(@clz(d[low]))
                                   - c_uint(@clz(n[high]));
            // 2 <= sr <= n_utword_bits - 1
            // q.all = a << (n_utword_bits - sr);
            // r.all = a >> sr;
            if (sr == n_udword_bits) {
                q[low] = 0;
                q[high] = n[low];
                r[high] = 0;
                r[low] = n[high];
            } else if (sr < n_udword_bits) {
                // 2 <= sr <= n_udword_bits - 1
                q[low] = 0;
                q[high] = n[low] << (n_udword_bits - sr);
                r[high] = n[high] >> sr;
                r[low] = (n[high] << (n_udword_bits - sr)) | (n[low] >> sr);
            } else {
                // n_udword_bits + 1 <= sr <= n_utword_bits - 1
                q[low] = n[low] << (n_utword_bits - sr);
                q[high] = (n[high] << (n_utword_bits - sr)) |
                           (n[low] >> (sr - n_udword_bits));
                r[high] = 0;
                r[low] = n[high] >> (sr - n_udword_bits);
            }
        } else {
            // K X
            // ---
            // K K
            sr = @bitCast(c_uint, c_int(@clz(d[high])) - c_int(@clz(n[high])));
            // 0 <= sr <= n_udword_bits - 1 or sr large
            if (sr > n_udword_bits - 1) {
               if (maybe_rem) |rem| {
                    *rem = a;
               }
                return 0;
            }
            sr += 1;
            // 1 <= sr <= n_udword_bits
            // q.all = a << (n_utword_bits - sr);
            // r.all = a >> sr;
            q[low] = 0;
            if (sr == n_udword_bits) {
                q[high] = n[low];
                r[high] = 0;
                r[low] = n[high];
            } else {
                r[high] = n[high] >> sr;
                r[low] = (n[high] << (n_udword_bits - sr)) | (n[low] >> sr);
                q[high] = n[low] << (n_udword_bits - sr);
            }
        }
    }
    // Not a special case
    // q and r are initialized with:
    // q.all = a << (n_utword_bits - sr);
    // r.all = a >> sr;
    // 1 <= sr <= n_utword_bits - 1
    var carry: u32 = 0;
    var r_all: u128 = undefined;
    while (sr > 0) : (sr -= 1) {
        // r:q = ((r:q)  << 1) | carry
        r[high] = (r[high] << 1) | (r[low]  >> (n_udword_bits - 1));
        r[low]  = (r[low]  << 1) | (q[high] >> (n_udword_bits - 1));
        q[high] = (q[high] << 1) | (q[low]  >> (n_udword_bits - 1));
        q[low]  = (q[low]  << 1) | carry;
        // carry = 0;
        // if (r.all >= b)
        // {
        //     r.all -= b;
        //      carry = 1;
        // }
        r_all = *@ptrCast(&u128, &r[0]); // TODO issue #421
        const s: i128 = i128(b -% r_all -% 1) >> (n_utword_bits - 1);
        carry = u32(s & 1);
        r_all -= b & @bitCast(u128, s);
        r = *@ptrCast(&[2]u64, &r_all); // TODO issue #421
    }
    const q_all = ((*@ptrCast(&u128, &q[0])) << 1) | carry; // TODO issue #421
    if (maybe_rem) |rem| {
        *rem = r_all;
    }
    return q_all;
}

test "import udivmodti4" {
    _ = @import("udivmodti4_test.zig");
}
