/*
 * Copyright (c) 2017 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_BIGINT_HPP
#define ZIG_BIGINT_HPP

#include <stdint.h>
#include <stddef.h>

struct BigInt {
    size_t digit_count;
    union {
        uint64_t digit;
        uint64_t *digits; // Least significant digit first
    } data;
    bool is_negative;
};

struct Buf;
struct BigFloat;

enum Cmp {
    CmpLT,
    CmpGT,
    CmpEQ,
};

void bigint_init_unsigned(BigInt *dest, uint64_t x);
void bigint_init_signed(BigInt *dest, int64_t x);
void bigint_init_bigint(BigInt *dest, const BigInt *src);
void bigint_init_bigfloat(BigInt *dest, const BigFloat *op);
void bigint_init_data(BigInt *dest, const uint64_t *digits, size_t digit_count, bool is_negative);
void bigint_deinit(BigInt *bi);

// panics if number won't fit
uint64_t bigint_as_u64(const BigInt *bigint);
uint32_t bigint_as_u32(const BigInt *bigint);
size_t bigint_as_usize(const BigInt *bigint);

int64_t bigint_as_signed(const BigInt *bigint);

static inline const uint64_t *bigint_ptr(const BigInt *bigint) {
    if (bigint->digit_count == 1) {
        return &bigint->data.digit;
    } else {
        return bigint->data.digits;
    }
}

bool bigint_fits_in_bits(const BigInt *bn, size_t bit_count, bool is_signed);
void bigint_write_twos_complement(const BigInt *big_int, uint8_t *buf, size_t bit_count, bool is_big_endian);
void bigint_read_twos_complement(BigInt *dest, const uint8_t *buf, size_t bit_count, bool is_big_endian,
        bool is_signed);
void bigint_add(BigInt *dest, const BigInt *op1, const BigInt *op2);
void bigint_add_wrap(BigInt *dest, const BigInt *op1, const BigInt *op2, size_t bit_count, bool is_signed);
void bigint_sub(BigInt *dest, const BigInt *op1, const BigInt *op2);
void bigint_sub_wrap(BigInt *dest, const BigInt *op1, const BigInt *op2, size_t bit_count, bool is_signed);
void bigint_mul(BigInt *dest, const BigInt *op1, const BigInt *op2);
void bigint_mul_wrap(BigInt *dest, const BigInt *op1, const BigInt *op2, size_t bit_count, bool is_signed);
void bigint_div_trunc(BigInt *dest, const BigInt *op1, const BigInt *op2);
void bigint_div_floor(BigInt *dest, const BigInt *op1, const BigInt *op2);
void bigint_rem(BigInt *dest, const BigInt *op1, const BigInt *op2);
void bigint_mod(BigInt *dest, const BigInt *op1, const BigInt *op2);

void bigint_or(BigInt *dest, const BigInt *op1, const BigInt *op2);
void bigint_and(BigInt *dest, const BigInt *op1, const BigInt *op2);
void bigint_xor(BigInt *dest, const BigInt *op1, const BigInt *op2);

void bigint_shl(BigInt *dest, const BigInt *op1, const BigInt *op2);
void bigint_shl_trunc(BigInt *dest, const BigInt *op1, const BigInt *op2, size_t bit_count, bool is_signed);
void bigint_shr(BigInt *dest, const BigInt *op1, const BigInt *op2);

void bigint_negate(BigInt *dest, const BigInt *op);
void bigint_negate_wrap(BigInt *dest, const BigInt *op, size_t bit_count);
void bigint_not(BigInt *dest, const BigInt *op, size_t bit_count, bool is_signed);
void bigint_truncate(BigInt *dest, const BigInt *op, size_t bit_count, bool is_signed);

Cmp bigint_cmp(const BigInt *op1, const BigInt *op2);

void bigint_append_buf(Buf *buf, const BigInt *op, uint64_t base);

size_t bigint_ctz(const BigInt *bi, size_t bit_count);
size_t bigint_clz(const BigInt *bi, size_t bit_count);
size_t bigint_popcount_signed(const BigInt *bi, size_t bit_count);
size_t bigint_popcount_unsigned(const BigInt *bi);

size_t bigint_bits_needed(const BigInt *op);


// convenience functions
Cmp bigint_cmp_zero(const BigInt *op);

void bigint_incr(BigInt *value);
void bigint_decr(BigInt *value);

bool mul_u64_overflow(uint64_t op1, uint64_t op2, uint64_t *result);

uint32_t bigint_hash(BigInt x);
bool bigint_eql(BigInt a, BigInt b);

#endif
