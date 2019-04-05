/*
 * Copyright (c) 2017 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_BIGFLOAT_HPP
#define ZIG_BIGFLOAT_HPP

#include "bigint.hpp"
#include "error.hpp"
#include <stdint.h>
#include <stddef.h>

#include "softfloat_types.h"


struct BigFloat {
    float128_t value;
};

struct Buf;

void bigfloat_init_16(BigFloat *dest, float16_t x);
void bigfloat_init_32(BigFloat *dest, float x);
void bigfloat_init_64(BigFloat *dest, double x);
void bigfloat_init_128(BigFloat *dest, float128_t x);
void bigfloat_init_bigfloat(BigFloat *dest, const BigFloat *x);
void bigfloat_init_bigint(BigFloat *dest, const BigInt *op);
Error bigfloat_init_buf(BigFloat *dest, const uint8_t *buf_ptr, size_t buf_len);

float16_t bigfloat_to_f16(const BigFloat *bigfloat);
float bigfloat_to_f32(const BigFloat *bigfloat);
double bigfloat_to_f64(const BigFloat *bigfloat);
float128_t bigfloat_to_f128(const BigFloat *bigfloat);

void bigfloat_add(BigFloat *dest, const BigFloat *op1, const BigFloat *op2);
void bigfloat_negate(BigFloat *dest, const BigFloat *op);
void bigfloat_sub(BigFloat *dest, const BigFloat *op1, const BigFloat *op2);
void bigfloat_mul(BigFloat *dest, const BigFloat *op1, const BigFloat *op2);
void bigfloat_div(BigFloat *dest, const BigFloat *op1, const BigFloat *op2);
void bigfloat_div_trunc(BigFloat *dest, const BigFloat *op1, const BigFloat *op2);
void bigfloat_div_floor(BigFloat *dest, const BigFloat *op1, const BigFloat *op2);
void bigfloat_rem(BigFloat *dest, const BigFloat *op1, const BigFloat *op2);
void bigfloat_mod(BigFloat *dest, const BigFloat *op1, const BigFloat *op2);
void bigfloat_sqrt(BigFloat *dest, const BigFloat *op);
void bigfloat_append_buf(Buf *buf, const BigFloat *op);
Cmp bigfloat_cmp(const BigFloat *op1, const BigFloat *op2);

bool bigfloat_is_nan(const BigFloat *op);

// convenience functions
Cmp bigfloat_cmp_zero(const BigFloat *bigfloat);
bool bigfloat_has_fraction(const BigFloat *bigfloat);

#endif
