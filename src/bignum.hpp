/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_BIGNUM_HPP
#define ZIG_BIGNUM_HPP

#include <stdint.h>

enum BigNumKind {
    BigNumKindInt,
    BigNumKindFloat,
};

struct BigNum {
    BigNumKind kind;
    bool is_negative;
    union {
        unsigned long long x_uint;
        double x_float;
    } data;
};

void bignum_init_float(BigNum *dest, double x);
void bignum_init_unsigned(BigNum *dest, uint64_t x);
void bignum_init_signed(BigNum *dest, int64_t x);
void bignum_init_bignum(BigNum *dest, BigNum *src);

bool bignum_fits_in_bits(BigNum *bn, int bit_count, bool is_signed);
uint64_t bignum_to_twos_complement(BigNum *bn);

// returns true if overflow happened
bool bignum_add(BigNum *dest, BigNum *op1, BigNum *op2);
bool bignum_sub(BigNum *dest, BigNum *op1, BigNum *op2);
bool bignum_mul(BigNum *dest, BigNum *op1, BigNum *op2);
bool bignum_div(BigNum *dest, BigNum *op1, BigNum *op2);
bool bignum_mod(BigNum *dest, BigNum *op1, BigNum *op2);

bool bignum_or(BigNum *dest, BigNum *op1, BigNum *op2);
bool bignum_and(BigNum *dest, BigNum *op1, BigNum *op2);
bool bignum_xor(BigNum *dest, BigNum *op1, BigNum *op2);
bool bignum_shl(BigNum *dest, BigNum *op1, BigNum *op2);
bool bignum_shr(BigNum *dest, BigNum *op1, BigNum *op2);

void bignum_negate(BigNum *dest, BigNum *op);
void bignum_cast_to_float(BigNum *dest, BigNum *op);
void bignum_cast_to_int(BigNum *dest, BigNum *op);

void bignum_truncate(BigNum *dest, int bit_count);

// returns the result of the comparison
bool bignum_cmp_eq(BigNum *op1, BigNum *op2);
bool bignum_cmp_neq(BigNum *op1, BigNum *op2);
bool bignum_cmp_lt(BigNum *op1, BigNum *op2);
bool bignum_cmp_gt(BigNum *op1, BigNum *op2);
bool bignum_cmp_lte(BigNum *op1, BigNum *op2);
bool bignum_cmp_gte(BigNum *op1, BigNum *op2);

// helper functions
bool bignum_increment_by_scalar(BigNum *bignum, uint64_t scalar);
bool bignum_multiply_by_scalar(BigNum *bignum, uint64_t scalar);

struct Buf;
Buf *bignum_to_buf(BigNum *bn);

#endif
