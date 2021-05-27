/*
 * Copyright (c) 2017 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "bigfloat.hpp"
#include "bigint.hpp"
#include "buffer.hpp"
#include "softfloat.hpp"
#include "softfloat_ext.hpp"
#include "parse_f128.h"
#include <stdio.h>
#include <math.h>
#include <errno.h>


void bigfloat_init_128(BigFloat *dest, float128_t x) {
    dest->value = x;
}

void bigfloat_init_16(BigFloat *dest, float16_t x) {
    f16_to_f128M(x, &dest->value);
}

void bigfloat_init_32(BigFloat *dest, float x) {
    float32_t f32_val;
    memcpy(&f32_val, &x, sizeof(float));
    f32_to_f128M(f32_val, &dest->value);
}

void bigfloat_init_64(BigFloat *dest, double x) {
    float64_t f64_val;
    memcpy(&f64_val, &x, sizeof(double));
    f64_to_f128M(f64_val, &dest->value);
}

void bigfloat_init_bigfloat(BigFloat *dest, const BigFloat *x) {
    memcpy(&dest->value, &x->value, sizeof(float128_t));
}

void bigfloat_init_bigint(BigFloat *dest, const BigInt *op) {
    ui32_to_f128M(0, &dest->value);
    if (op->digit_count == 0)
        return;

    float128_t base;
    ui64_to_f128M(UINT64_MAX, &base);
    float128_t one_f128;
    ui32_to_f128M(1, &one_f128);
    f128M_add(&base, &one_f128, &base);

    const uint64_t *digits = bigint_ptr(op);

    for (size_t i = op->digit_count - 1;;) {
        float128_t digit_f128;
        ui64_to_f128M(digits[i], &digit_f128);

        f128M_mulAdd(&dest->value, &base, &digit_f128, &dest->value);

        if (i == 0) {
            if (op->is_negative) {
                f128M_neg(&dest->value, &dest->value);
            }
            return;
        }
        i -= 1;
    }
}

Error bigfloat_init_buf(BigFloat *dest, const uint8_t *buf_ptr) {
    char *str_begin = (char *)buf_ptr;
    char *str_end;

    errno = 0;
    dest->value = parse_f128(str_begin, &str_end);
    if (errno) {
        return ErrorOverflow;
    }

    return ErrorNone;
}

void bigfloat_add(BigFloat *dest, const BigFloat *op1, const BigFloat *op2) {
    f128M_add(&op1->value, &op2->value, &dest->value);
}

void bigfloat_negate(BigFloat *dest, const BigFloat *op) {
    f128M_neg(&op->value, &dest->value);
}

void bigfloat_sub(BigFloat *dest, const BigFloat *op1, const BigFloat *op2) {
    f128M_sub(&op1->value, &op2->value, &dest->value);
}

void bigfloat_mul(BigFloat *dest, const BigFloat *op1, const BigFloat *op2) {
    f128M_mul(&op1->value, &op2->value, &dest->value);
}

void bigfloat_div(BigFloat *dest, const BigFloat *op1, const BigFloat *op2) {
    f128M_div(&op1->value, &op2->value, &dest->value);
}

void bigfloat_div_trunc(BigFloat *dest, const BigFloat *op1, const BigFloat *op2) {
    f128M_div(&op1->value, &op2->value, &dest->value);
    f128M_roundToInt(&dest->value, softfloat_round_minMag, false, &dest->value);
}

void bigfloat_div_floor(BigFloat *dest, const BigFloat *op1, const BigFloat *op2) {
    f128M_div(&op1->value, &op2->value, &dest->value);
    f128M_roundToInt(&dest->value, softfloat_round_min, false, &dest->value);
}

void bigfloat_rem(BigFloat *dest, const BigFloat *op1, const BigFloat *op2) {
    f128M_rem(&op1->value, &op2->value, &dest->value);
}

void bigfloat_mod(BigFloat *dest, const BigFloat *op1, const BigFloat *op2) {
    f128M_rem(&op1->value, &op2->value, &dest->value);
    f128M_add(&dest->value, &op2->value, &dest->value);
    f128M_rem(&dest->value, &op2->value, &dest->value);
}

void bigfloat_append_buf(Buf *buf, const BigFloat *op) {
    const size_t extra_len = 100;
    size_t old_len = buf_len(buf);
    buf_resize(buf, old_len + extra_len);

    // TODO actually print f128
    float64_t f64_value = f128M_to_f64(&op->value);
    double double_value;
    memcpy(&double_value, &f64_value, sizeof(double));

    int len = snprintf(buf_ptr(buf) + old_len, extra_len, "%f", double_value);
    assert(len > 0);
    buf_resize(buf, old_len + len);
}

Cmp bigfloat_cmp(const BigFloat *op1, const BigFloat *op2) {
    if (f128M_lt(&op1->value, &op2->value)) {
        return CmpLT;
    } else if (f128M_eq(&op1->value, &op2->value)) {
        return CmpEQ;
    } else {
        return CmpGT;
    }
}

float16_t bigfloat_to_f16(const BigFloat *bigfloat) {
    return f128M_to_f16(&bigfloat->value);
}

float bigfloat_to_f32(const BigFloat *bigfloat) {
    float32_t f32_value = f128M_to_f32(&bigfloat->value);
    float result;
    memcpy(&result, &f32_value, sizeof(float));
    return result;
}

double bigfloat_to_f64(const BigFloat *bigfloat) {
    float64_t f64_value = f128M_to_f64(&bigfloat->value);
    double result;
    memcpy(&result, &f64_value, sizeof(double));
    return result;
}

float128_t bigfloat_to_f128(const BigFloat *bigfloat) {
    return bigfloat->value;
}

Cmp bigfloat_cmp_zero(const BigFloat *bigfloat) {
    float128_t zero_float;
    ui32_to_f128M(0, &zero_float);
    if (f128M_lt(&bigfloat->value, &zero_float)) {
        return CmpLT;
    } else if (f128M_eq(&bigfloat->value, &zero_float)) {
        return CmpEQ;
    } else {
        return CmpGT;
    }
}

bool bigfloat_has_fraction(const BigFloat *bigfloat) {
    float128_t floored;
    f128M_roundToInt(&bigfloat->value, softfloat_round_minMag, false, &floored);
    return !f128M_eq(&floored, &bigfloat->value);
}

void bigfloat_sqrt(BigFloat *dest, const BigFloat *op) {
    f128M_sqrt(&op->value, &dest->value);
}

bool bigfloat_is_nan(const BigFloat *op) {
    return f128M_isSignalingNaN(&op->value);
}
