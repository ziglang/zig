/*
 * Copyright (c) 2017 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "bigfloat.hpp"
#include "bigint.hpp"
#include "buffer.hpp"
#include "quadmath.hpp"
#include <math.h>
#include <errno.h>

void bigfloat_init_128(BigFloat *dest, __float128 x) {
    dest->value = x;
}

void bigfloat_init_32(BigFloat *dest, float x) {
    dest->value = x;
}

void bigfloat_init_64(BigFloat *dest, double x) {
    dest->value = x;
}

void bigfloat_init_bigfloat(BigFloat *dest, const BigFloat *x) {
    dest->value = x->value;
}

void bigfloat_init_bigint(BigFloat *dest, const BigInt *op) {
    dest->value = 0.0;
    if (op->digit_count == 0)
        return;

    __float128 base = (__float128)UINT64_MAX;
    const uint64_t *digits = bigint_ptr(op);

    for (size_t i = op->digit_count - 1;;) {
        uint64_t digit = digits[i];
        dest->value *= base;
        dest->value += (__float128)digit;

        if (i == 0) {
            if (op->is_negative) {
                dest->value = -dest->value;
            }
            return;
        }
        i -= 1;
    }
}

int bigfloat_init_buf_base10(BigFloat *dest, const uint8_t *buf_ptr, size_t buf_len) {
    char *str_begin = (char *)buf_ptr;
    char *str_end;
    errno = 0;
    dest->value = strtoflt128(str_begin, &str_end);
    if (errno) {
        return ErrorOverflow;
    }
    assert(str_end <= ((char*)buf_ptr) + buf_len);
    return 0;
}

void bigfloat_add(BigFloat *dest, const BigFloat *op1, const BigFloat *op2) {
    dest->value = op1->value + op2->value;
}

void bigfloat_negate(BigFloat *dest, const BigFloat *op) {
    dest->value = -op->value;
}

void bigfloat_sub(BigFloat *dest, const BigFloat *op1, const BigFloat *op2) {
    dest->value = op1->value - op2->value;
}

void bigfloat_mul(BigFloat *dest, const BigFloat *op1, const BigFloat *op2) {
    dest->value = op1->value * op2->value;
}

void bigfloat_div(BigFloat *dest, const BigFloat *op1, const BigFloat *op2) {
    dest->value = op1->value / op2->value;
}

void bigfloat_div_trunc(BigFloat *dest, const BigFloat *op1, const BigFloat *op2) {
    dest->value = op1->value / op2->value;
    if (dest->value >= 0.0) {
        dest->value = floorq(dest->value);
    } else {
        dest->value = ceilq(dest->value);
    }
}

void bigfloat_div_floor(BigFloat *dest, const BigFloat *op1, const BigFloat *op2) {
    dest->value = floorq(op1->value / op2->value);
}

void bigfloat_rem(BigFloat *dest, const BigFloat *op1, const BigFloat *op2) {
    dest->value = fmodq(op1->value, op2->value);
}

void bigfloat_mod(BigFloat *dest, const BigFloat *op1, const BigFloat *op2) {
    dest->value = fmodq(fmodq(op1->value, op2->value) + op2->value, op2->value);
}

void bigfloat_append_buf(Buf *buf, const BigFloat *op) {
    const size_t extra_len = 100;
    size_t old_len = buf_len(buf);
    buf_resize(buf, old_len + extra_len);
    int len = quadmath_snprintf(buf_ptr(buf) + old_len, extra_len, "%Qf", op->value);
    assert(len > 0);
    buf_resize(buf, old_len + len);
}

Cmp bigfloat_cmp(const BigFloat *op1, const BigFloat *op2) {
    if (op1->value > op2->value) {
        return CmpGT;
    } else if (op1->value < op2->value) {
        return CmpLT;
    } else {
        return CmpEQ;
    }
}

float bigfloat_to_f32(const BigFloat *bigfloat) {
    return (float)bigfloat->value;
}

double bigfloat_to_f64(const BigFloat *bigfloat) {
    return (double)bigfloat->value;
}

__float128 bigfloat_to_f128(const BigFloat *bigfloat) {
    return bigfloat->value;
}

Cmp bigfloat_cmp_zero(const BigFloat *bigfloat) {
    if (bigfloat->value < 0.0) {
        return CmpLT;
    } else if (bigfloat->value > 0.0) {
        return CmpGT;
    } else {
        return CmpEQ;
    }
}

bool bigfloat_has_fraction(const BigFloat *bigfloat) {
    return floorq(bigfloat->value) != bigfloat->value;
}
