const CHAR_BIT = 8;
const du_int = u64;
const di_int = i64;
const si_int = c_int;
const su_int = c_uint;

const udwords = [2]su_int;
const low = if (@compileVar("is_big_endian")) 1 else 0;
const high = 1 - low;

export fn __udivdi3(a: du_int, b: du_int) -> du_int {
    @setDebugSafety(this, false);
    return __udivmoddi4(a, b, null);
}

fn du_int_to_udwords(x: du_int) -> udwords {
    @setDebugSafety(this, false);
    return *(&udwords)(&x);
}

export fn __udivmoddi4(a: du_int, b: du_int, maybe_rem: ?&du_int) -> du_int {
    @setDebugSafety(this, false);

    const n_uword_bits = @sizeOf(su_int) * CHAR_BIT;
    const n_udword_bits = @sizeOf(du_int) * CHAR_BIT;
    var n = du_int_to_udwords(a);
    var d = du_int_to_udwords(b);
    var q: udwords = undefined;
    var r: udwords = undefined;
    var sr: c_uint = undefined;
    // special cases, X is unknown, K != 0
    if (n[high] == 0) {
        if (d[high] == 0) {
            // 0 X
            // ---
            // 0 X
            if (const rem ?= maybe_rem) {
                *rem = n[low] % d[low];
            }
            return n[low] / d[low];
        }
        // 0 X
        // ---
        // K X
        if (const rem ?= maybe_rem) {
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
            if (var rem ?= maybe_rem) {
                *rem = n[high] % d[low];
            }
            return n[high] / d[low];
        }
        // d[high] != 0
        if (n[low] == 0) {
            // K 0
            // ---
            // K 0
            if (var rem ?= maybe_rem) {
                r[high] = n[high] % d[high];
                r[low] = 0;
                *rem = *(&du_int)(&r[0]);
            }
            return n[high] / d[high];
        }
        // K K
        // ---
        // K 0
        // if d is a power of 2
        if ((d[high] & (d[high] - 1)) == 0) {
            if (var rem ?= maybe_rem) {
                r[low] = n[low];
                r[high] = n[high] & (d[high] - 1);
                *rem = *(&du_int)(&r[0]);
            }
            return n[high] >> @ctz(@typeOf(d[high]), d[high]);
        }
        // K K
        // ---
        // K 0
        sr = @clz(su_int, d[high]) - @clz(su_int, n[high]);
        // 0 <= sr <= n_uword_bits - 2 or sr large
        if (sr > n_uword_bits - 2) {
            if (var rem ?= maybe_rem) {
                *rem = *(&du_int)(&n[0]);
            }
            return 0;
        }
        sr += 1;
        // 1 <= sr <= n_uword_bits - 1
        // q.all = n.all << (n_udword_bits - sr);
        q[low] = 0;
        q[high] = n[low] << (n_uword_bits - sr);
        // r.all = n.all >> sr;
        r[high] = n[high] >> sr;
        r[low] = (n[high] << (n_uword_bits - sr)) | (n[low] >> sr);
    } else {
        // d[low] != 0
        if (d[high] == 0) {
            // K X
            // ---
            // 0 K
            // if d is a power of 2
            if ((d[low] & (d[low] - 1)) == 0) {
                if (var rem ?= maybe_rem) {
                    *rem = n[low] & (d[low] - 1);
                }
                if (d[low] == 1) {
                    return *(&du_int)(&n[0]);
                }
                sr = @ctz(@typeOf(d[low]), d[low]);
                q[high] = n[high] >> sr;
                q[low] = (n[high] << (n_uword_bits - sr)) | (n[low] >> sr);
                return *(&du_int)(&q[0]);
            }
            // K X
            // ---
            // 0 K
            sr = 1 + n_uword_bits + @clz(su_int, d[low]) - @clz(su_int, n[high]);
            // 2 <= sr <= n_udword_bits - 1
            // q.all = n.all << (n_udword_bits - sr);
            // r.all = n.all >> sr;
            if (sr == n_uword_bits) {
                q[low] = 0;
                q[high] = n[low];
                r[high] = 0;
                r[low] = n[high];
            } else if (sr < n_uword_bits) {
                // 2 <= sr <= n_uword_bits - 1
                q[low] = 0;
                q[high] = n[low] << (n_uword_bits - sr);
                r[high] = n[high] >> sr;
                r[low] = (n[high] << (n_uword_bits - sr)) | (n[low] >> sr);
            } else {
                // n_uword_bits + 1 <= sr <= n_udword_bits - 1
                q[low] = n[low] << (n_udword_bits - sr);
                q[high] = (n[high] << (n_udword_bits - sr)) |
                    (n[low] >> (sr - n_uword_bits));
                r[high] = 0;
                r[low] = n[high] >> (sr - n_uword_bits);
            }
        } else {
            // K X
            // ---
            // K K
            sr = @clz(su_int, d[high]) - @clz(su_int, n[high]);
            // 0 <= sr <= n_uword_bits - 1 or sr large
            if (sr > n_uword_bits - 1) {
                if (var rem ?= maybe_rem) {
                    *rem = *(&du_int)(&n[0]);
                }
                return 0;
            }
            sr += 1;
            // 1 <= sr <= n_uword_bits
            //  q.all = n.all << (n_udword_bits - sr);
            q[low] = 0;
            if (sr == n_uword_bits) {
                q[high] = n[low];
                r[high] = 0;
                r[low] = n[high];
            } else {
                q[high] = n[low] << (n_uword_bits - sr);
                r[high] = n[high] >> sr;
                r[low] = (n[high] << (n_uword_bits - sr)) | (n[low] >> sr);
            }
        }
    }
    // Not a special case
    // q and r are initialized with:
    // q.all = n.all << (n_udword_bits - sr);
    // r.all = n.all >> sr;
    // 1 <= sr <= n_udword_bits - 1
    var carry: su_int = 0;
    while (sr > 0) {
        // r:q = ((r:q)  << 1) | carry
        r[high] = (r[high] << 1) | (r[low]  >> (n_uword_bits - 1));
        r[low]  = (r[low]  << 1) | (q[high] >> (n_uword_bits - 1));
        q[high] = (q[high] << 1) | (q[low]  >> (n_uword_bits - 1));
        q[low]  = (q[low]  << 1) | carry;
        // carry = 0;
        // if (r.all >= d.all)
        // {
        //      r.all -= d.all;
        //      carry = 1;
        // }
        const s: di_int = (di_int)(*(&du_int)(&d[0]) - *(&du_int)(&r[0]) - 1) >> (n_udword_bits - 1);
        carry = su_int(s & 1);
        *(&du_int)(&r[0]) -= *(&du_int)(&d[0]) & u64(s);

        sr -= 1;
    }
    *(&du_int)(&q[0]) = (*(&du_int)(&q[0]) << 1) | u64(carry);
    if (var rem ?= maybe_rem) {
        *rem = *(&du_int)(&r[0]);
    }
    return *(&du_int)(&q[0]);
}

export fn __umoddi3(a: du_int, b: du_int) -> du_int {
    @setDebugSafety(this, false);

    var r: du_int = undefined;
    __udivmoddi4(a, b, &r);
    return r;
}

fn test_umoddi3() {
    @setFnTest(this, true);

    test_one_umoddi3(0, 1, 0);
    test_one_umoddi3(2, 1, 0);
    test_one_umoddi3(0x8000000000000000, 1, 0x0);
    test_one_umoddi3(0x8000000000000000, 2, 0x0);
    test_one_umoddi3(0xFFFFFFFFFFFFFFFF, 2, 0x1);
}

fn test_one_umoddi3(a: du_int, b: du_int, expected_r: du_int) {
    const r = __umoddi3(a, b);
    assert(r == expected_r);
}

fn test_udivmoddi4() {
    @setFnTest(this, true);

    const cases = [][4]du_int {
        []du_int{0x0000000000000000, 0x0000000000000001, 0x0000000000000000, 0x0000000000000000},
        []du_int{0x0000000080000000, 0x0000000100000001, 0x0000000000000000, 0x0000000080000000},
        []du_int{0x7FFFFFFF00000001, 0x0000000000000001, 0x7FFFFFFF00000001, 0x0000000000000000},
        []du_int{0x7FFFFFFF7FFFFFFF, 0xFFFFFFFFFFFFFFFF, 0x0000000000000000, 0x7FFFFFFF7FFFFFFF},
        []du_int{0x8000000000000002, 0xFFFFFFFFFFFFFFFE, 0x0000000000000000, 0x8000000000000002},
        []du_int{0x80000000FFFFFFFD, 0xFFFFFFFFFFFFFFFD, 0x0000000000000000, 0x80000000FFFFFFFD},
        []du_int{0xFFFFFFFD00000010, 0xFFFFFFFF80000000, 0x0000000000000000, 0xFFFFFFFD00000010},
        []du_int{0xFFFFFFFDFFFFFFFF, 0xFFFFFFFF7FFFFFFF, 0x0000000000000000, 0xFFFFFFFDFFFFFFFF},
        []du_int{0xFFFFFFFE0747AE14, 0xFFFFFFFF0747AE14, 0x0000000000000000, 0xFFFFFFFE0747AE14},
        []du_int{0xFFFFFFFF00000001, 0xFFFFFFFF078644FA, 0x0000000000000000, 0xFFFFFFFF00000001},
        []du_int{0xFFFFFFFF80000000, 0xFFFFFFFF00000010, 0x0000000000000001, 0x000000007FFFFFF0},
        []du_int{0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0x0000000000000001, 0x0000000000000000},
    };

    for (cases) |case| {
        test_one_udivmoddi4(case[0], case[1], case[2], case[3]);
    }
}

fn test_one_udivmoddi4(a: du_int, b: du_int, expected_q: du_int, expected_r: du_int) {
    var r: du_int = undefined;
    const q = __udivmoddi4(a, b, &r);
    assert(q == expected_q);
    assert(r == expected_r);
}

fn assert(b: bool) {
    if (!b) @unreachable();
}
