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

struct BigFloat {
    __float128 value;
};

struct Buf;

void bigfloat_init_float(BigFloat *dest, __float128 x);
void bigfloat_init_bigfloat(BigFloat *dest, const BigFloat *x);
void bigfloat_init_bigint(BigFloat *dest, const BigInt *op);
int bigfloat_init_buf_base10(BigFloat *dest, const uint8_t *buf_ptr, size_t buf_len);

double bigfloat_to_double(const BigFloat *bigfloat);

void bigfloat_add(BigFloat *dest, const BigFloat *op1, const BigFloat *op2);
void bigfloat_negate(BigFloat *dest, const BigFloat *op);
void bigfloat_sub(BigFloat *dest, const BigFloat *op1, const BigFloat *op2);
void bigfloat_mul(BigFloat *dest, const BigFloat *op1, const BigFloat *op2);
void bigfloat_div(BigFloat *dest, const BigFloat *op1, const BigFloat *op2);
void bigfloat_div_trunc(BigFloat *dest, const BigFloat *op1, const BigFloat *op2);
void bigfloat_div_floor(BigFloat *dest, const BigFloat *op1, const BigFloat *op2);
void bigfloat_rem(BigFloat *dest, const BigFloat *op1, const BigFloat *op2);
void bigfloat_mod(BigFloat *dest, const BigFloat *op1, const BigFloat *op2);
void bigfloat_write_buf(Buf *buf, const BigFloat *op);
Cmp bigfloat_cmp(const BigFloat *op1, const BigFloat *op2);
void bigfloat_write_ieee597(const BigFloat *op, uint8_t *buf, size_t bit_count, bool is_big_endian);
void bigfloat_read_ieee597(BigFloat *dest, const uint8_t *buf, size_t bit_count, bool is_big_endian);


// convenience functions
Cmp bigfloat_cmp_zero(const BigFloat *bigfloat);
bool bigfloat_has_fraction(const BigFloat *bigfloat);

#endif
