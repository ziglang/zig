/*
 * Copyright (c) 2017 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_SOFTFLOAT_HPP
#define ZIG_SOFTFLOAT_HPP

extern "C" {
#include "softfloat.h"
}

static inline float16_t zig_double_to_f16(double x) {
    float64_t y;
    static_assert(sizeof(x) == sizeof(y), "");
    memcpy(&y, &x, sizeof(x));
    return f64_to_f16(y);
}


// Return value is safe to coerce to float even when |x| is NaN or Infinity.
static inline double zig_f16_to_double(float16_t x) {
    float64_t y = f16_to_f64(x);
    double z;
    static_assert(sizeof(y) == sizeof(z), "");
    memcpy(&z, &y, sizeof(y));
    return z;
}

static inline bool zig_f16_isNaN(float16_t a) {
    union { uint16_t ui; float16_t f; } uA;
    uA.f = a;
    return 0x7C00 < (uA.ui & 0x7FFF);
}

static inline bool zig_f128_isNaN(float128_t *aPtr) {
    uint64_t absA64 = aPtr->v[1] & UINT64_C(0x7FFFFFFFFFFFFFFF);
    return
        (UINT64_C(0x7FFF000000000000) < absA64)
            || ((absA64 == UINT64_C(0x7FFF000000000000)) && aPtr->v[0]);
}

#endif
