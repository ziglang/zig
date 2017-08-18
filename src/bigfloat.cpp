/*
 * Copyright (c) 2017 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "bigfloat.hpp"
#include "bigint.hpp"
#include "buffer.hpp"
#include <math.h>
#include <errno.h>

extern "C" {
    __float128 fmodq(__float128 a, __float128 b);
    __float128 ceilq(__float128 a);
    __float128 floorq(__float128 a);
    __float128 strtoflt128 (const char *s, char **sp);
    int quadmath_snprintf (char *s, size_t size, const char *format, ...);
}


void bigfloat_init_float(BigFloat *dest, __float128 x) {
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

void bigfloat_write_buf(Buf *buf, const BigFloat *op) {
    buf_resize(buf, 256);
    int len = quadmath_snprintf(buf_ptr(buf), buf_len(buf), "%Qf", op->value);
    assert(len > 0);
    buf_resize(buf, len);
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

// TODO this is wrong when compiler running on big endian systems. caught by tests
void bigfloat_write_ieee597(const BigFloat *op, uint8_t *buf, size_t bit_count, bool is_big_endian) {
    if (bit_count == 32) {
        float f32 = op->value;
        memcpy(buf, &f32, 4);
    } else if (bit_count == 64) {
        double f64 = op->value;
        memcpy(buf, &f64, 8);
    } else if (bit_count == 128) {
        __float128 f128 = op->value;
        memcpy(buf, &f128, 16);
    } else {
        zig_unreachable();
    }
}

// TODO this is wrong when compiler running on big endian systems. caught by tests
void bigfloat_read_ieee597(BigFloat *dest, const uint8_t *buf, size_t bit_count, bool is_big_endian) {
    if (bit_count == 32) {
        float f32;
        memcpy(&f32, buf, 4);
        dest->value = f32;
    } else if (bit_count == 64) {
        double f64;
        memcpy(&f64, buf, 8);
        dest->value = f64;
    } else if (bit_count == 128) {
        __float128 f128;
        memcpy(&f128, buf, 16);
        dest->value = f128;
    } else {
        zig_unreachable();
    }
}

double bigfloat_to_double(const BigFloat *bigfloat) {
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
