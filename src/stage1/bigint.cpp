/*
 * Copyright (c) 2017 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "bigfloat.hpp"
#include "bigint.hpp"
#include "buffer.hpp"
#include "list.hpp"
#include "os.hpp"
#include "softfloat.hpp"

#include <limits>
#include <algorithm>

static uint64_t bigint_as_unsigned(const BigInt *bigint);

static void bigint_normalize(BigInt *dest) {
    const uint64_t *digits = bigint_ptr(dest);

    size_t last_nonzero_digit = SIZE_MAX;
    for (size_t i = 0; i < dest->digit_count; i += 1) {
        uint64_t digit = digits[i];
        if (digit != 0) {
            last_nonzero_digit = i;
        }
    }
    if (last_nonzero_digit == SIZE_MAX) {
        dest->is_negative = false;
        dest->digit_count = 0;
    } else {
        dest->digit_count = last_nonzero_digit + 1;
        if (last_nonzero_digit == 0) {
            dest->data.digit = digits[0];
        }
    }
}

static uint8_t digit_to_char(uint8_t digit, bool uppercase) {
    if (digit <= 9) {
        return digit + '0';
    } else if (digit <= 35) {
        return (digit - 10) + (uppercase ? 'A' : 'a');
    } else {
        zig_unreachable();
    }
}

size_t bigint_bits_needed(const BigInt *op) {
    size_t full_bits = op->digit_count * 64;
    size_t leading_zero_count = bigint_clz(op, full_bits);
    size_t bits_needed = full_bits - leading_zero_count;
    return bits_needed + op->is_negative;
}

static void to_twos_complement(BigInt *dest, const BigInt *op, size_t bit_count) {
    if (bit_count == 0 || op->digit_count == 0) {
        bigint_init_unsigned(dest, 0);
        return;
    }
    if (op->is_negative) {
        BigInt negated = {0};
        bigint_negate(&negated, op);

        BigInt inverted = {0};
        bigint_not(&inverted, &negated, bit_count, false);

        BigInt one = {0};
        bigint_init_unsigned(&one, 1);

        bigint_add(dest, &inverted, &one);
        return;
    }

    dest->is_negative = false;
    const uint64_t *op_digits = bigint_ptr(op);
    if (op->digit_count == 1) {
        dest->data.digit = op_digits[0];
        if (bit_count < 64) {
            dest->data.digit &= (1ULL << bit_count) - 1;
        }
        dest->digit_count = 1;
        bigint_normalize(dest);
        return;
    }
    size_t digits_to_copy = bit_count / 64;
    size_t leftover_bits = bit_count % 64;
    dest->digit_count = digits_to_copy + ((leftover_bits == 0) ? 0 : 1);
    if (dest->digit_count == 1 && leftover_bits == 0) {
        dest->data.digit = op_digits[0];
        if (dest->data.digit == 0) dest->digit_count = 0;
        return;
    }
    dest->data.digits = heap::c_allocator.allocate_nonzero<uint64_t>(dest->digit_count);
    for (size_t i = 0; i < digits_to_copy; i += 1) {
        uint64_t digit = (i < op->digit_count) ? op_digits[i] : 0;
        dest->data.digits[i] = digit;
    }
    if (leftover_bits != 0) {
        uint64_t digit = (digits_to_copy < op->digit_count) ? op_digits[digits_to_copy] : 0;
        dest->data.digits[digits_to_copy] = digit & ((1ULL << leftover_bits) - 1);
    }
    bigint_normalize(dest);
}

static bool bit_at_index(const BigInt *bi, size_t index) {
    size_t digit_index = index / 64;
    if (digit_index >= bi->digit_count)
        return false;
    size_t digit_bit_index = index % 64;
    const uint64_t *digits = bigint_ptr(bi);
    uint64_t digit = digits[digit_index];
    return ((digit >> digit_bit_index) & 0x1) == 0x1;
}

static void from_twos_complement(BigInt *dest, const BigInt *src, size_t bit_count, bool is_signed) {
    assert(!src->is_negative);

    if (bit_count == 0 || src->digit_count == 0) {
        bigint_init_unsigned(dest, 0);
        return;
    }

    if (is_signed && bit_at_index(src, bit_count - 1)) {
        BigInt negative_one = {0};
        bigint_init_signed(&negative_one, -1);

        BigInt minus_one = {0};
        bigint_add(&minus_one, src, &negative_one);

        BigInt inverted = {0};
        bigint_not(&inverted, &minus_one, bit_count, false);

        bigint_negate(dest, &inverted);
        return;

    }

    bigint_init_bigint(dest, src);
}

void bigint_init_unsigned(BigInt *dest, uint64_t x) {
    if (x == 0) {
        dest->digit_count = 0;
        dest->is_negative = false;
        return;
    }
    dest->digit_count = 1;
    dest->data.digit = x;
    dest->is_negative = false;
}

void bigint_init_signed(BigInt *dest, int64_t x) {
    if (x >= 0) {
        return bigint_init_unsigned(dest, x);
    }
    dest->is_negative = true;
    dest->digit_count = 1;
    dest->data.digit = ((uint64_t)(-(x + 1))) + 1;
}

void bigint_init_data(BigInt *dest, const uint64_t *digits, size_t digit_count, bool is_negative) {
    if (digit_count == 0) {
        return bigint_init_unsigned(dest, 0);
    } else if (digit_count == 1) {
        dest->digit_count = 1;
        dest->data.digit = digits[0];
        dest->is_negative = is_negative;
        bigint_normalize(dest);
        return;
    }

    dest->digit_count = digit_count;
    dest->is_negative = is_negative;
    dest->data.digits = heap::c_allocator.allocate_nonzero<uint64_t>(digit_count);
    memcpy(dest->data.digits, digits, sizeof(uint64_t) * digit_count);

    bigint_normalize(dest);
}

void bigint_init_bigint(BigInt *dest, const BigInt *src) {
    if (src->digit_count == 0) {
        return bigint_init_unsigned(dest, 0);
    } else if (src->digit_count == 1) {
        dest->digit_count = 1;
        dest->data.digit = src->data.digit;
        dest->is_negative = src->is_negative;
        return;
    }
    dest->is_negative = src->is_negative;
    dest->digit_count = src->digit_count;
    dest->data.digits = heap::c_allocator.allocate_nonzero<uint64_t>(dest->digit_count);
    memcpy(dest->data.digits, src->data.digits, sizeof(uint64_t) * dest->digit_count);
}

void bigint_deinit(BigInt *bi) {
    if (bi->digit_count > 1)
        heap::c_allocator.deallocate(bi->data.digits, bi->digit_count);
}

void bigint_init_bigfloat(BigInt *dest, const BigFloat *op) {
    float128_t zero;
    ui32_to_f128M(0, &zero);

    dest->is_negative = f128M_lt(&op->value, &zero);
    float128_t abs_val;
    if (dest->is_negative) {
        f128M_sub(&zero, &op->value, &abs_val);
    } else {
        memcpy(&abs_val, &op->value, sizeof(float128_t));
    }

    float128_t max_u64;
    ui64_to_f128M(UINT64_MAX, &max_u64);
    if (f128M_le(&abs_val, &max_u64)) {
        dest->digit_count = 1;
        dest->data.digit = f128M_to_ui64(&op->value, softfloat_round_minMag, false);
        bigint_normalize(dest);
        return;
    }

    float128_t amt;
    f128M_div(&abs_val, &max_u64, &amt);
    float128_t remainder;
    f128M_rem(&abs_val, &max_u64, &remainder);

    dest->digit_count = 2;
    dest->data.digits = heap::c_allocator.allocate_nonzero<uint64_t>(dest->digit_count);
    dest->data.digits[0] = f128M_to_ui64(&remainder, softfloat_round_minMag, false);
    dest->data.digits[1] = f128M_to_ui64(&amt, softfloat_round_minMag, false);
    bigint_normalize(dest);
}

bool bigint_fits_in_bits(const BigInt *bn, size_t bit_count, bool is_signed) {
    assert(bn->digit_count != 1 || bn->data.digit != 0);
    if (bit_count == 0) {
        return bigint_cmp_zero(bn) == CmpEQ;
    }
    if (bn->digit_count == 0) {
        return true;
    }

    if (!is_signed) {
        if(bn->is_negative) return false;
        size_t full_bits = bn->digit_count * 64;
        size_t leading_zero_count = bigint_clz(bn, full_bits);
        return bit_count >= full_bits - leading_zero_count;
    }

    BigInt one = {0};
    bigint_init_unsigned(&one, 1);

    BigInt shl_amt = {0};
    bigint_init_unsigned(&shl_amt, bit_count - 1);

    BigInt max_value_plus_one = {0};
    bigint_shl(&max_value_plus_one, &one, &shl_amt);

    BigInt max_value = {0};
    bigint_sub(&max_value, &max_value_plus_one, &one);

    BigInt min_value = {0};
    bigint_negate(&min_value, &max_value_plus_one);

    Cmp min_cmp = bigint_cmp(bn, &min_value);
    Cmp max_cmp = bigint_cmp(bn, &max_value);

    return (min_cmp == CmpGT || min_cmp == CmpEQ) && (max_cmp == CmpLT || max_cmp == CmpEQ);
}

void bigint_write_twos_complement(const BigInt *big_int, uint8_t *buf, size_t bit_count, bool is_big_endian) {
    if (bit_count == 0)
        return;

    BigInt twos_comp = {0};
    to_twos_complement(&twos_comp, big_int, bit_count);

    const uint64_t *twos_comp_digits = bigint_ptr(&twos_comp);

    size_t bits_in_last_digit = bit_count % 64;
    if (bits_in_last_digit == 0) bits_in_last_digit = 64;
    size_t bytes_in_last_digit = (bits_in_last_digit + 7) / 8;
    size_t unwritten_byte_count = 8 - bytes_in_last_digit;

    if (is_big_endian) {
        size_t last_digit_index = (bit_count - 1) / 64;
        size_t digit_index = last_digit_index;
        size_t buf_index = 0;
        for (;;) {
            uint64_t x = (digit_index < twos_comp.digit_count) ? twos_comp_digits[digit_index] : 0;

            for (size_t byte_index = 7;;) {
                uint8_t byte = x & 0xff;
                if (digit_index == last_digit_index) {
                    buf[buf_index + byte_index - unwritten_byte_count] = byte;
                    if (byte_index == unwritten_byte_count) break;
                } else {
                    buf[buf_index + byte_index] = byte;
                }

                if (byte_index == 0) break;
                byte_index -= 1;
                x >>= 8;
            }

            if (digit_index == 0) break;
            digit_index -= 1;
            if (digit_index == last_digit_index) {
                buf_index += bytes_in_last_digit;
            } else {
                buf_index += 8;
            }
        }
    } else {
        size_t digit_count = (bit_count + 63) / 64;
        size_t buf_index = 0;
        for (size_t digit_index = 0; digit_index < digit_count; digit_index += 1) {
            uint64_t x = (digit_index < twos_comp.digit_count) ? twos_comp_digits[digit_index] : 0;

            for (size_t byte_index = 0;
                byte_index < 8 && (digit_index + 1 < digit_count || byte_index < bytes_in_last_digit);
                byte_index += 1)
            {
                uint8_t byte = x & 0xff;
                buf[buf_index] = byte;
                buf_index += 1;
                x >>= 8;
            }
        }
    }
}


void bigint_read_twos_complement(BigInt *dest, const uint8_t *buf, size_t bit_count, bool is_big_endian,
        bool is_signed)
{
    if (bit_count == 0) {
        bigint_init_unsigned(dest, 0);
        return;
    }

    dest->digit_count = (bit_count + 63) / 64;
    uint64_t *digits;
    if (dest->digit_count == 1) {
        digits = &dest->data.digit;
    } else {
        digits = heap::c_allocator.allocate_nonzero<uint64_t>(dest->digit_count);
        dest->data.digits = digits;
    }

    size_t bits_in_last_digit = bit_count % 64;
    if (bits_in_last_digit == 0) {
        bits_in_last_digit = 64;
    }
    size_t bytes_in_last_digit = (bits_in_last_digit + 7) / 8;
    size_t unread_byte_count = 8 - bytes_in_last_digit;

    if (is_big_endian) {
        size_t buf_index = 0;
        uint64_t digit = 0;
        for (size_t byte_index = unread_byte_count; byte_index < 8; byte_index += 1) {
            uint8_t byte = buf[buf_index];
            buf_index += 1;
            digit <<= 8;
            digit |= byte;
        }
        digits[dest->digit_count - 1] = digit;
        for (size_t digit_index = 1; digit_index < dest->digit_count; digit_index += 1) {
            digit = 0;
            for (size_t byte_index = 0; byte_index < 8; byte_index += 1) {
                uint8_t byte = buf[buf_index];
                buf_index += 1;
                digit <<= 8;
                digit |= byte;
            }
            digits[dest->digit_count - 1 - digit_index] = digit;
        }
    } else {
        size_t buf_index = 0;
        for (size_t digit_index = 0; digit_index < dest->digit_count; digit_index += 1) {
            uint64_t digit = 0;
            size_t end_byte_index = (digit_index == dest->digit_count - 1) ? bytes_in_last_digit : 8;
            for (size_t byte_index = 0; byte_index < end_byte_index; byte_index += 1) {
                uint64_t byte = buf[buf_index];
                buf_index += 1;

                digit |= byte << (8 * byte_index);
            }
            digits[digit_index] = digit;
        }
    }

    if (is_signed) {
        bigint_normalize(dest);
        BigInt tmp = {0};
        bigint_init_bigint(&tmp, dest);
        from_twos_complement(dest, &tmp, bit_count, true);
    } else {
        dest->is_negative = false;
        bigint_normalize(dest);
    }
}

#if defined(_MSC_VER)
static bool add_u64_overflow(uint64_t op1, uint64_t op2, uint64_t *result) {
   *result = op1 + op2;
   return *result < op1 || *result < op2;
}

static bool sub_u64_overflow(uint64_t op1, uint64_t op2, uint64_t *result) {
   *result = op1 - op2;
   return *result > op1;
}

bool mul_u64_overflow(uint64_t op1, uint64_t op2, uint64_t *result) {
    *result = op1 * op2;

    if (op1 == 0 || op2 == 0)
        return false;

    if (op1 > UINT64_MAX / op2)
        return true;

    if (op2 > UINT64_MAX / op1)
        return true;

    return false;
}
#else
static bool add_u64_overflow(uint64_t op1, uint64_t op2, uint64_t *result) {
    return __builtin_uaddll_overflow((unsigned long long)op1, (unsigned long long)op2,
            (unsigned long long *)result);
}

static bool sub_u64_overflow(uint64_t op1, uint64_t op2, uint64_t *result) {
    return __builtin_usubll_overflow((unsigned long long)op1, (unsigned long long)op2,
            (unsigned long long *)result);
}

bool mul_u64_overflow(uint64_t op1, uint64_t op2, uint64_t *result) {
    return __builtin_umulll_overflow((unsigned long long)op1, (unsigned long long)op2,
            (unsigned long long *)result);
}
#endif

void bigint_add(BigInt *dest, const BigInt *op1, const BigInt *op2) {
    if (op1->digit_count == 0) {
        return bigint_init_bigint(dest, op2);
    }
    if (op2->digit_count == 0) {
        return bigint_init_bigint(dest, op1);
    }
    if (op1->is_negative == op2->is_negative) {
        dest->is_negative = op1->is_negative;

        const uint64_t *op1_digits = bigint_ptr(op1);
        const uint64_t *op2_digits = bigint_ptr(op2);
        bool overflow = add_u64_overflow(op1_digits[0], op2_digits[0], &dest->data.digit);
        if (overflow == 0 && op1->digit_count == 1 && op2->digit_count == 1) {
            dest->digit_count = 1;
            bigint_normalize(dest);
            return;
        }
        size_t i = 1;
        uint64_t first_digit = dest->data.digit;
        dest->data.digits = heap::c_allocator.allocate_nonzero<uint64_t>(max(op1->digit_count, op2->digit_count) + 1);
        dest->data.digits[0] = first_digit;

        for (;;) {
            bool found_digit = false;
            uint64_t x = overflow;
            overflow = 0;

            if (i < op1->digit_count) {
                found_digit = true;
                uint64_t digit = op1_digits[i];
                overflow += add_u64_overflow(x, digit, &x);
            }

            if (i < op2->digit_count) {
                found_digit = true;
                uint64_t digit = op2_digits[i];
                overflow += add_u64_overflow(x, digit, &x);
            }

            dest->data.digits[i] = x;
            i += 1;

            if (!found_digit) {
                dest->digit_count = i;
                bigint_normalize(dest);
                return;
            }
        }
    }
    const BigInt *op_pos;
    const BigInt *op_neg;
    if (op1->is_negative) {
        op_neg = op1;
        op_pos = op2;
    } else {
        op_pos = op1;
        op_neg = op2;
    }

    BigInt op_neg_abs = {0};
    bigint_negate(&op_neg_abs, op_neg);
    const BigInt *bigger_op;
    const BigInt *smaller_op;
    switch (bigint_cmp(op_pos, &op_neg_abs)) {
        case CmpEQ:
            bigint_init_unsigned(dest, 0);
            return;
        case CmpLT:
            bigger_op = &op_neg_abs;
            smaller_op = op_pos;
            dest->is_negative = true;
            break;
        case CmpGT:
            bigger_op = op_pos;
            smaller_op = &op_neg_abs;
            dest->is_negative = false;
            break;
    }
    const uint64_t *bigger_op_digits = bigint_ptr(bigger_op);
    const uint64_t *smaller_op_digits = bigint_ptr(smaller_op);
    uint64_t overflow = sub_u64_overflow(bigger_op_digits[0], smaller_op_digits[0], &dest->data.digit);
    if (overflow == 0 && bigger_op->digit_count == 1 && smaller_op->digit_count == 1) {
        dest->digit_count = 1;
        bigint_normalize(dest);
        return;
    }
    uint64_t first_digit = dest->data.digit;
    dest->data.digits = heap::c_allocator.allocate_nonzero<uint64_t>(bigger_op->digit_count);
    dest->data.digits[0] = first_digit;
    size_t i = 1;

    for (;;) {
        bool found_digit = false;
        uint64_t x = bigger_op_digits[i];
        uint64_t prev_overflow = overflow;
        overflow = 0;

        if (i < smaller_op->digit_count) {
            found_digit = true;
            uint64_t digit = smaller_op_digits[i];
            overflow += sub_u64_overflow(x, digit, &x);
        }
        if (sub_u64_overflow(x, prev_overflow, &x)) {
            found_digit = true;
            overflow += 1;
        }
        dest->data.digits[i] = x;
        i += 1;

        if (!found_digit || i >= bigger_op->digit_count)
            break;
    }
    assert(overflow == 0);
    dest->digit_count = i;
    bigint_normalize(dest);
}

void bigint_add_wrap(BigInt *dest, const BigInt *op1, const BigInt *op2, size_t bit_count, bool is_signed) {
    BigInt unwrapped = {0};
    bigint_add(&unwrapped, op1, op2);
    bigint_truncate(dest, &unwrapped, bit_count, is_signed);
}

void bigint_sub(BigInt *dest, const BigInt *op1, const BigInt *op2) {
    BigInt op2_negated = {0};
    bigint_negate(&op2_negated, op2);
    return bigint_add(dest, op1, &op2_negated);
}

void bigint_sub_wrap(BigInt *dest, const BigInt *op1, const BigInt *op2, size_t bit_count, bool is_signed) {
    BigInt op2_negated = {0};
    bigint_negate(&op2_negated, op2);
    return bigint_add_wrap(dest, op1, &op2_negated, bit_count, is_signed);
}

static void mul_overflow(uint64_t op1, uint64_t op2, uint64_t *lo, uint64_t *hi) {
    uint64_t u1 = (op1 & 0xffffffff);
    uint64_t v1 = (op2 & 0xffffffff);
    uint64_t t = (u1 * v1);
    uint64_t w3 = (t & 0xffffffff);
    uint64_t k = (t >> 32);

    op1 >>= 32;
    t = (op1 * v1) + k;
    k = (t & 0xffffffff);
    uint64_t w1 = (t >> 32);

    op2 >>= 32;
    t = (u1 * op2) + k;
    k = (t >> 32);

    *hi = (op1 * op2) + w1 + k;
    *lo = (t << 32) + w3;
}

static void mul_scalar(BigInt *dest, const BigInt *op, uint64_t scalar) {
    bigint_init_unsigned(dest, 0);

    BigInt bi_64;
    bigint_init_unsigned(&bi_64, 64);

    const uint64_t *op_digits = bigint_ptr(op);
    size_t i = op->digit_count - 1;

    for (;;) {
        BigInt shifted;
        bigint_shl(&shifted, dest, &bi_64);

        uint64_t result_scalar;
        uint64_t carry_scalar;
        mul_overflow(scalar, op_digits[i], &result_scalar, &carry_scalar);

        BigInt result;
        bigint_init_unsigned(&result, result_scalar);

        BigInt carry;
        bigint_init_unsigned(&carry, carry_scalar);

        BigInt carry_shifted;
        bigint_shl(&carry_shifted, &carry, &bi_64);

        BigInt tmp;
        bigint_add(&tmp, &shifted, &carry_shifted);

        bigint_add(dest, &tmp, &result);

        if (i == 0) {
            break;
        }
        i -= 1;
    }
}

void bigint_mul(BigInt *dest, const BigInt *op1, const BigInt *op2) {
    if (op1->digit_count == 0 || op2->digit_count == 0) {
        return bigint_init_unsigned(dest, 0);
    }
    const uint64_t *op1_digits = bigint_ptr(op1);
    const uint64_t *op2_digits = bigint_ptr(op2);

    uint64_t carry;
    mul_overflow(op1_digits[0], op2_digits[0], &dest->data.digit, &carry);
    if (carry == 0 && op1->digit_count == 1 && op2->digit_count == 1) {
        dest->is_negative = (op1->is_negative != op2->is_negative);
        dest->digit_count = 1;
        bigint_normalize(dest);
        return;
    }

    bigint_init_unsigned(dest, 0);

    BigInt bi_64;
    bigint_init_unsigned(&bi_64, 64);

    size_t i = op2->digit_count - 1;
    for (;;) {
        BigInt shifted;
        bigint_shl(&shifted, dest, &bi_64);

        BigInt scalar_result;
        mul_scalar(&scalar_result, op1, op2_digits[i]);

        bigint_add(dest, &scalar_result, &shifted);

        if (i == 0) {
            break;
        }
        i -= 1;
    }

    dest->is_negative = (op1->is_negative != op2->is_negative);
    bigint_normalize(dest);
}

void bigint_mul_wrap(BigInt *dest, const BigInt *op1, const BigInt *op2, size_t bit_count, bool is_signed) {
    BigInt unwrapped = {0};
    bigint_mul(&unwrapped, op1, op2);
    bigint_truncate(dest, &unwrapped, bit_count, is_signed);
}

enum ZeroBehavior {
  /// \brief The returned value is undefined.
  ZB_Undefined,
  /// \brief The returned value is numeric_limits<T>::max()
  ZB_Max,
  /// \brief The returned value is numeric_limits<T>::digits
  ZB_Width
};

template <typename T, std::size_t SizeOfT> struct LeadingZerosCounter {
  static std::size_t count(T Val, ZeroBehavior) {
    if (!Val)
      return std::numeric_limits<T>::digits;

    // Bisection method.
    std::size_t ZeroBits = 0;
    for (T Shift = std::numeric_limits<T>::digits >> 1; Shift; Shift >>= 1) {
      T Tmp = Val >> Shift;
      if (Tmp)
        Val = Tmp;
      else
        ZeroBits |= Shift;
    }
    return ZeroBits;
  }
};

#if __GNUC__ >= 4 || defined(_MSC_VER)
template <typename T> struct LeadingZerosCounter<T, 4> {
  static std::size_t count(T Val, ZeroBehavior ZB) {
    if (ZB != ZB_Undefined && Val == 0)
      return 32;

#if defined(_MSC_VER)
    unsigned long Index;
    _BitScanReverse(&Index, Val);
    return Index ^ 31;
#else
    return __builtin_clz(Val);
#endif
  }
};

#if !defined(_MSC_VER) || defined(_M_X64)
template <typename T> struct LeadingZerosCounter<T, 8> {
  static std::size_t count(T Val, ZeroBehavior ZB) {
    if (ZB != ZB_Undefined && Val == 0)
      return 64;

#if defined(_MSC_VER)
    unsigned long Index;
    _BitScanReverse64(&Index, Val);
    return Index ^ 63;
#else
    return __builtin_clzll(Val);
#endif
  }
};
#endif
#endif

/// \brief Count number of 0's from the most significant bit to the least
///   stopping at the first 1.
///
/// Only unsigned integral types are allowed.
///
/// \param ZB the behavior on an input of 0. Only ZB_Width and ZB_Undefined are
///   valid arguments.
template <typename T>
std::size_t countLeadingZeros(T Val, ZeroBehavior ZB = ZB_Width) {
  static_assert(std::numeric_limits<T>::is_integer &&
                    !std::numeric_limits<T>::is_signed,
                "Only unsigned integral types are allowed.");
  return LeadingZerosCounter<T, sizeof(T)>::count(Val, ZB);
}

/// Make a 64-bit integer from a high / low pair of 32-bit integers.
constexpr inline uint64_t Make_64(uint32_t High, uint32_t Low) {
  return ((uint64_t)High << 32) | (uint64_t)Low;
}

/// Return the high 32 bits of a 64 bit value.
constexpr inline uint32_t Hi_32(uint64_t Value) {
  return static_cast<uint32_t>(Value >> 32);
}

/// Return the low 32 bits of a 64 bit value.
constexpr inline uint32_t Lo_32(uint64_t Value) {
  return static_cast<uint32_t>(Value);
}

/// Implementation of Knuth's Algorithm D (Division of nonnegative integers)
/// from "Art of Computer Programming, Volume 2", section 4.3.1, p. 272. The
/// variables here have the same names as in the algorithm. Comments explain
/// the algorithm and any deviation from it.
static void KnuthDiv(uint32_t *u, uint32_t *v, uint32_t *q, uint32_t* r,
                     unsigned m, unsigned n)
{
    assert(u && "Must provide dividend");
    assert(v && "Must provide divisor");
    assert(q && "Must provide quotient");
    assert(u != v && u != q && v != q && "Must use different memory");
    assert(n>1 && "n must be > 1");

    // b denotes the base of the number system. In our case b is 2^32.
    const uint64_t b = uint64_t(1) << 32;

    // D1. [Normalize.] Set d = b / (v[n-1] + 1) and multiply all the digits of
    // u and v by d. Note that we have taken Knuth's advice here to use a power
    // of 2 value for d such that d * v[n-1] >= b/2 (b is the base). A power of
    // 2 allows us to shift instead of multiply and it is easy to determine the
    // shift amount from the leading zeros.  We are basically normalizing the u
    // and v so that its high bits are shifted to the top of v's range without
    // overflow. Note that this can require an extra word in u so that u must
    // be of length m+n+1.
    unsigned shift = countLeadingZeros(v[n-1]);
    uint32_t v_carry = 0;
    uint32_t u_carry = 0;
    if (shift) {
        for (unsigned i = 0; i < m+n; ++i) {
            uint32_t u_tmp = u[i] >> (32 - shift);
            u[i] = (u[i] << shift) | u_carry;
            u_carry = u_tmp;
        }
        for (unsigned i = 0; i < n; ++i) {
            uint32_t v_tmp = v[i] >> (32 - shift);
            v[i] = (v[i] << shift) | v_carry;
            v_carry = v_tmp;
        }
    }
    u[m+n] = u_carry;

    // D2. [Initialize j.]  Set j to m. This is the loop counter over the places.
    int j = m;
    do {
        // D3. [Calculate q'.].
        //     Set qp = (u[j+n]*b + u[j+n-1]) / v[n-1]. (qp=qprime=q')
        //     Set rp = (u[j+n]*b + u[j+n-1]) % v[n-1]. (rp=rprime=r')
        // Now test if qp == b or qp*v[n-2] > b*rp + u[j+n-2]; if so, decrease
        // qp by 1, increase rp by v[n-1], and repeat this test if rp < b. The test
        // on v[n-2] determines at high speed most of the cases in which the trial
        // value qp is one too large, and it eliminates all cases where qp is two
        // too large.
        uint64_t dividend = Make_64(u[j+n], u[j+n-1]);
        uint64_t qp = dividend / v[n-1];
        uint64_t rp = dividend % v[n-1];
        if (qp == b || qp*v[n-2] > b*rp + u[j+n-2]) {
            qp--;
            rp += v[n-1];
            if (rp < b && (qp == b || qp*v[n-2] > b*rp + u[j+n-2]))
                qp--;
        }

        // D4. [Multiply and subtract.] Replace (u[j+n]u[j+n-1]...u[j]) with
        // (u[j+n]u[j+n-1]..u[j]) - qp * (v[n-1]...v[1]v[0]). This computation
        // consists of a simple multiplication by a one-place number, combined with
        // a subtraction.
        // The digits (u[j+n]...u[j]) should be kept positive; if the result of
        // this step is actually negative, (u[j+n]...u[j]) should be left as the
        // true value plus b**(n+1), namely as the b's complement of
        // the true value, and a "borrow" to the left should be remembered.
        int64_t borrow = 0;
        for (unsigned i = 0; i < n; ++i) {
            uint64_t p = uint64_t(qp) * uint64_t(v[i]);
            int64_t subres = int64_t(u[j+i]) - borrow - Lo_32(p);
            u[j+i] = Lo_32(subres);
            borrow = Hi_32(p) - Hi_32(subres);
        }
        bool isNeg = u[j+n] < borrow;
        u[j+n] -= Lo_32(borrow);

        // D5. [Test remainder.] Set q[j] = qp. If the result of step D4 was
        // negative, go to step D6; otherwise go on to step D7.
        q[j] = Lo_32(qp);
        if (isNeg) {
            // D6. [Add back]. The probability that this step is necessary is very
            // small, on the order of only 2/b. Make sure that test data accounts for
            // this possibility. Decrease q[j] by 1
            q[j]--;
            // and add (0v[n-1]...v[1]v[0]) to (u[j+n]u[j+n-1]...u[j+1]u[j]).
            // A carry will occur to the left of u[j+n], and it should be ignored
            // since it cancels with the borrow that occurred in D4.
            bool carry = false;
            for (unsigned i = 0; i < n; i++) {
                uint32_t limit = std::min(u[j+i],v[i]);
                u[j+i] += v[i] + carry;
                carry = u[j+i] < limit || (carry && u[j+i] == limit);
            }
            u[j+n] += carry;
        }

        // D7. [Loop on j.]  Decrease j by one. Now if j >= 0, go back to D3.
    } while (--j >= 0);

    // D8. [Unnormalize]. Now q[...] is the desired quotient, and the desired
    // remainder may be obtained by dividing u[...] by d. If r is non-null we
    // compute the remainder (urem uses this).
    if (r) {
        // The value d is expressed by the "shift" value above since we avoided
        // multiplication by d by using a shift left. So, all we have to do is
        // shift right here.
        if (shift) {
            uint32_t carry = 0;
            for (int i = n-1; i >= 0; i--) {
                r[i] = (u[i] >> shift) | carry;
                carry = u[i] << (32 - shift);
            }
        } else {
            for (int i = n-1; i >= 0; i--) {
                r[i] = u[i];
            }
        }
    }
}

// Implementation ported from LLVM/lib/Support/APInt.cpp
static void bigint_unsigned_division(const BigInt *op1, const BigInt *op2, BigInt *Quotient, BigInt *Remainder) {
    Cmp cmp = bigint_cmp(op1, op2);
    if (cmp == CmpLT) {
        if (Quotient != nullptr) {
            bigint_init_unsigned(Quotient, 0);
        }
        if (Remainder != nullptr) {
            bigint_init_bigint(Remainder, op1);
        }
        return;
    }
    if (cmp == CmpEQ) {
        if (Quotient != nullptr) {
            bigint_init_unsigned(Quotient, 1);
        }
        if (Remainder != nullptr) {
            bigint_init_unsigned(Remainder, 0);
        }
        return;
    }

    const uint64_t *LHS = bigint_ptr(op1);
    const uint64_t *RHS = bigint_ptr(op2);
    unsigned lhsWords = op1->digit_count;
    unsigned rhsWords = op2->digit_count;

    // First, compose the values into an array of 32-bit words instead of
    // 64-bit words. This is a necessity of both the "short division" algorithm
    // and the Knuth "classical algorithm" which requires there to be native
    // operations for +, -, and * on an m bit value with an m*2 bit result. We
    // can't use 64-bit operands here because we don't have native results of
    // 128-bits. Furthermore, casting the 64-bit values to 32-bit values won't
    // work on large-endian machines.
    unsigned n = rhsWords * 2;
    unsigned m = (lhsWords * 2) - n;

    // Allocate space for the temporary values we need either on the stack, if
    // it will fit, or on the heap if it won't.
    uint32_t SPACE[128];
    uint32_t *U = nullptr;
    uint32_t *V = nullptr;
    uint32_t *Q = nullptr;
    uint32_t *R = nullptr;
    if ((Remainder?4:3)*n+2*m+1 <= 128) {
        U = &SPACE[0];
        V = &SPACE[m+n+1];
        Q = &SPACE[(m+n+1) + n];
        if (Remainder)
            R = &SPACE[(m+n+1) + n + (m+n)];
    } else {
        U = new uint32_t[m + n + 1];
        V = new uint32_t[n];
        Q = new uint32_t[m+n];
        if (Remainder)
            R = new uint32_t[n];
    }

    // Initialize the dividend
    memset(U, 0, (m+n+1)*sizeof(uint32_t));
    for (unsigned i = 0; i < lhsWords; ++i) {
        uint64_t tmp = LHS[i];
        U[i * 2] = Lo_32(tmp);
        U[i * 2 + 1] = Hi_32(tmp);
    }
    U[m+n] = 0; // this extra word is for "spill" in the Knuth algorithm.

    // Initialize the divisor
    memset(V, 0, (n)*sizeof(uint32_t));
    for (unsigned i = 0; i < rhsWords; ++i) {
        uint64_t tmp = RHS[i];
        V[i * 2] = Lo_32(tmp);
        V[i * 2 + 1] = Hi_32(tmp);
    }

    // initialize the quotient and remainder
    memset(Q, 0, (m+n) * sizeof(uint32_t));
    if (Remainder)
        memset(R, 0, n * sizeof(uint32_t));

    // Now, adjust m and n for the Knuth division. n is the number of words in
    // the divisor. m is the number of words by which the dividend exceeds the
    // divisor (i.e. m+n is the length of the dividend). These sizes must not
    // contain any zero words or the Knuth algorithm fails.
    for (unsigned i = n; i > 0 && V[i-1] == 0; i--) {
        n--;
        m++;
    }
    for (unsigned i = m+n; i > 0 && U[i-1] == 0; i--)
        m--;

    // If we're left with only a single word for the divisor, Knuth doesn't work
    // so we implement the short division algorithm here. This is much simpler
    // and faster because we are certain that we can divide a 64-bit quantity
    // by a 32-bit quantity at hardware speed and short division is simply a
    // series of such operations. This is just like doing short division but we
    // are using base 2^32 instead of base 10.
    assert(n != 0 && "Divide by zero?");
    if (n == 1) {
        uint32_t divisor = V[0];
        uint32_t remainder = 0;
        for (int i = m; i >= 0; i--) {
            uint64_t partial_dividend = Make_64(remainder, U[i]);
            if (partial_dividend == 0) {
                Q[i] = 0;
                remainder = 0;
            } else if (partial_dividend < divisor) {
                Q[i] = 0;
                remainder = Lo_32(partial_dividend);
            } else if (partial_dividend == divisor) {
                Q[i] = 1;
                remainder = 0;
            } else {
                Q[i] = Lo_32(partial_dividend / divisor);
                remainder = Lo_32(partial_dividend - (Q[i] * divisor));
            }
        }
        if (R)
            R[0] = remainder;
    } else {
        // Now we're ready to invoke the Knuth classical divide algorithm. In this
        // case n > 1.
        KnuthDiv(U, V, Q, R, m, n);
    }

    // If the caller wants the quotient
    if (Quotient) {
        Quotient->is_negative = false;
        Quotient->digit_count = lhsWords;
        if (lhsWords == 1) {
            Quotient->data.digit = Make_64(Q[1], Q[0]);
        } else {
            Quotient->data.digits = heap::c_allocator.allocate<uint64_t>(lhsWords);
            for (size_t i = 0; i < lhsWords; i += 1) {
                Quotient->data.digits[i] = Make_64(Q[i*2+1], Q[i*2]);
            }
        }
    }

    // If the caller wants the remainder
    if (Remainder) {
        Remainder->is_negative = false;
        Remainder->digit_count = rhsWords;
        if (rhsWords == 1) {
            Remainder->data.digit = Make_64(R[1], R[0]);
        } else {
            Remainder->data.digits = heap::c_allocator.allocate<uint64_t>(rhsWords);
            for (size_t i = 0; i < rhsWords; i += 1) {
                Remainder->data.digits[i] = Make_64(R[i*2+1], R[i*2]);
            }
        }
    }
}

void bigint_div_trunc(BigInt *dest, const BigInt *op1, const BigInt *op2) {
    assert(op2->digit_count != 0); // division by zero
    if (op1->digit_count == 0) {
        bigint_init_unsigned(dest, 0);
        return;
    }
    const uint64_t *op1_digits = bigint_ptr(op1);
    const uint64_t *op2_digits = bigint_ptr(op2);
    if (op1->digit_count == 1 && op2->digit_count == 1) {
        dest->data.digit = op1_digits[0] / op2_digits[0];
        dest->digit_count = 1;
        dest->is_negative = op1->is_negative != op2->is_negative;
        bigint_normalize(dest);
        return;
    }
    if (op2->digit_count == 1 && op2_digits[0] == 1) {
        // X / 1 == X
        bigint_init_bigint(dest, op1);
        dest->is_negative = op1->is_negative != op2->is_negative;
        bigint_normalize(dest);
        return;
    }

    const BigInt *op1_positive;
    BigInt op1_positive_data;
    if (op1->is_negative) {
        bigint_negate(&op1_positive_data, op1);
        op1_positive = &op1_positive_data;
    } else {
        op1_positive = op1;
    }

    const BigInt *op2_positive;
    BigInt op2_positive_data;
    if (op2->is_negative) {
        bigint_negate(&op2_positive_data, op2);
        op2_positive = &op2_positive_data;
    } else {
        op2_positive = op2;
    }

    bigint_unsigned_division(op1_positive, op2_positive, dest, nullptr);
    dest->is_negative = op1->is_negative != op2->is_negative;
    bigint_normalize(dest);
}

void bigint_div_floor(BigInt *dest, const BigInt *op1, const BigInt *op2) {
    if (op1->is_negative != op2->is_negative) {
        bigint_div_trunc(dest, op1, op2);
        BigInt mult_again = {0};
        bigint_mul(&mult_again, dest, op2);
        mult_again.is_negative = op1->is_negative;
        if (bigint_cmp(&mult_again, op1) != CmpEQ) {
            BigInt tmp = {0};
            bigint_init_bigint(&tmp, dest);
            BigInt neg_one = {0};
            bigint_init_signed(&neg_one, -1);
            bigint_add(dest, &tmp, &neg_one);
        }
        bigint_normalize(dest);
    } else {
        bigint_div_trunc(dest, op1, op2);
    }
}

void bigint_rem(BigInt *dest, const BigInt *op1, const BigInt *op2) {
    assert(op2->digit_count != 0); // division by zero
    if (op1->digit_count == 0) {
        bigint_init_unsigned(dest, 0);
        return;
    }
    const uint64_t *op1_digits = bigint_ptr(op1);
    const uint64_t *op2_digits = bigint_ptr(op2);

    if (op1->digit_count == 1 && op2->digit_count == 1) {
        dest->data.digit = op1_digits[0] % op2_digits[0];
        dest->digit_count = 1;
        dest->is_negative = op1->is_negative;
        bigint_normalize(dest);
        return;
    }
    if (op2->digit_count == 2 && op2_digits[0] == 0 && op2_digits[1] == 1) {
        // special case this divisor
        bigint_init_unsigned(dest, op1_digits[0]);
        dest->is_negative = op1->is_negative;
        bigint_normalize(dest);
        return;
    }

    if (op2->digit_count == 1 && op2_digits[0] == 1) {
        // X % 1 == 0
        bigint_init_unsigned(dest, 0);
        return;
    }

    const BigInt *op1_positive;
    BigInt op1_positive_data;
    if (op1->is_negative) {
        bigint_negate(&op1_positive_data, op1);
        op1_positive = &op1_positive_data;
    } else {
        op1_positive = op1;
    }

    const BigInt *op2_positive;
    BigInt op2_positive_data;
    if (op2->is_negative) {
        bigint_negate(&op2_positive_data, op2);
        op2_positive = &op2_positive_data;
    } else {
        op2_positive = op2;
    }

    bigint_unsigned_division(op1_positive, op2_positive, nullptr, dest);
    dest->is_negative = op1->is_negative;
    bigint_normalize(dest);
}

void bigint_mod(BigInt *dest, const BigInt *op1, const BigInt *op2) {
    if (op1->is_negative) {
        BigInt first_rem;
        bigint_rem(&first_rem, op1, op2);
        first_rem.is_negative = !op2->is_negative;
        BigInt op2_minus_rem;
        bigint_add(&op2_minus_rem, op2, &first_rem);
        bigint_rem(dest, &op2_minus_rem, op2);
        dest->is_negative = false;
    } else {
        bigint_rem(dest, op1, op2);
        dest->is_negative = false;
    }
}

void bigint_or(BigInt *dest, const BigInt *op1, const BigInt *op2) {
    if (op1->digit_count == 0) {
        return bigint_init_bigint(dest, op2);
    }
    if (op2->digit_count == 0) {
        return bigint_init_bigint(dest, op1);
    }
    if (op1->is_negative || op2->is_negative) {
        size_t big_bit_count = max(bigint_bits_needed(op1), bigint_bits_needed(op2));

        BigInt twos_comp_op1 = {0};
        to_twos_complement(&twos_comp_op1, op1, big_bit_count);

        BigInt twos_comp_op2 = {0};
        to_twos_complement(&twos_comp_op2, op2, big_bit_count);

        BigInt twos_comp_dest = {0};
        bigint_or(&twos_comp_dest, &twos_comp_op1, &twos_comp_op2);

        from_twos_complement(dest, &twos_comp_dest, big_bit_count, true);
    } else {
        dest->is_negative = false;
        const uint64_t *op1_digits = bigint_ptr(op1);
        const uint64_t *op2_digits = bigint_ptr(op2);
        if (op1->digit_count == 1 && op2->digit_count == 1) {
            dest->digit_count = 1;
            dest->data.digit = op1_digits[0] | op2_digits[0];
            bigint_normalize(dest);
            return;
        }
        dest->digit_count = max(op1->digit_count, op2->digit_count);
        dest->data.digits = heap::c_allocator.allocate_nonzero<uint64_t>(dest->digit_count);
        for (size_t i = 0; i < dest->digit_count; i += 1) {
            uint64_t digit = 0;
            if (i < op1->digit_count) {
                digit |= op1_digits[i];
            }
            if (i < op2->digit_count) {
                digit |= op2_digits[i];
            }
            dest->data.digits[i] = digit;
        }
        bigint_normalize(dest);
    }
}

void bigint_and(BigInt *dest, const BigInt *op1, const BigInt *op2) {
    if (op1->digit_count == 0 || op2->digit_count == 0) {
        return bigint_init_unsigned(dest, 0);
    }
    if (op1->is_negative || op2->is_negative) {
        size_t big_bit_count = max(bigint_bits_needed(op1), bigint_bits_needed(op2));

        BigInt twos_comp_op1 = {0};
        to_twos_complement(&twos_comp_op1, op1, big_bit_count);

        BigInt twos_comp_op2 = {0};
        to_twos_complement(&twos_comp_op2, op2, big_bit_count);

        BigInt twos_comp_dest = {0};
        bigint_and(&twos_comp_dest, &twos_comp_op1, &twos_comp_op2);

        from_twos_complement(dest, &twos_comp_dest, big_bit_count, true);
    } else {
        dest->is_negative = false;
        const uint64_t *op1_digits = bigint_ptr(op1);
        const uint64_t *op2_digits = bigint_ptr(op2);
        if (op1->digit_count == 1 && op2->digit_count == 1) {
            dest->digit_count = 1;
            dest->data.digit = op1_digits[0] & op2_digits[0];
            bigint_normalize(dest);
            return;
        }

        dest->digit_count = max(op1->digit_count, op2->digit_count);
        dest->data.digits = heap::c_allocator.allocate_nonzero<uint64_t>(dest->digit_count);

        size_t i = 0;
        for (; i < op1->digit_count && i < op2->digit_count; i += 1) {
            dest->data.digits[i] = op1_digits[i] & op2_digits[i];
        }
        for (; i < dest->digit_count; i += 1) {
            dest->data.digits[i] = 0;
        }
        bigint_normalize(dest);
    }
}

void bigint_xor(BigInt *dest, const BigInt *op1, const BigInt *op2) {
    if (op1->digit_count == 0) {
        return bigint_init_bigint(dest, op2);
    }
    if (op2->digit_count == 0) {
        return bigint_init_bigint(dest, op1);
    }
    if (op1->is_negative || op2->is_negative) {
        size_t big_bit_count = max(bigint_bits_needed(op1), bigint_bits_needed(op2));

        BigInt twos_comp_op1 = {0};
        to_twos_complement(&twos_comp_op1, op1, big_bit_count);

        BigInt twos_comp_op2 = {0};
        to_twos_complement(&twos_comp_op2, op2, big_bit_count);

        BigInt twos_comp_dest = {0};
        bigint_xor(&twos_comp_dest, &twos_comp_op1, &twos_comp_op2);

        from_twos_complement(dest, &twos_comp_dest, big_bit_count, true);
    } else {
        dest->is_negative = false;
        const uint64_t *op1_digits = bigint_ptr(op1);
        const uint64_t *op2_digits = bigint_ptr(op2);

        assert(op1->digit_count > 0 && op2->digit_count > 0);
        if (op1->digit_count == 1 && op2->digit_count == 1) {
            dest->digit_count = 1;
            dest->data.digit = op1_digits[0] ^ op2_digits[0];
            bigint_normalize(dest);
            return;
        }
        dest->digit_count = max(op1->digit_count, op2->digit_count);
        dest->data.digits = heap::c_allocator.allocate_nonzero<uint64_t>(dest->digit_count);
        size_t i = 0;
        for (; i < op1->digit_count && i < op2->digit_count; i += 1) {
            dest->data.digits[i] = op1_digits[i] ^ op2_digits[i];
        }
        for (; i < dest->digit_count; i += 1) {
            if (i < op1->digit_count) {
                dest->data.digits[i] = op1_digits[i];
            } else if (i < op2->digit_count) {
                dest->data.digits[i] = op2_digits[i];
            } else {
                zig_unreachable();
            }
        }
        bigint_normalize(dest);
    }
}

void bigint_shl(BigInt *dest, const BigInt *op1, const BigInt *op2) {
    assert(!op2->is_negative);

    if (op2->digit_count == 0) {
        bigint_init_bigint(dest, op1);
        return;
    }

    if (op1->digit_count == 0) {
        bigint_init_unsigned(dest, 0);
        return;
    }

    if (op2->digit_count != 1) {
        zig_panic("TODO shift left by amount greater than 64 bit integer");
    }

    const uint64_t *op1_digits = bigint_ptr(op1);
    uint64_t shift_amt = bigint_as_unsigned(op2);

    if (op1->digit_count == 1 && shift_amt < 64) {
        dest->data.digit = op1_digits[0] << shift_amt;
        if (dest->data.digit > op1_digits[0]) {
            dest->digit_count = 1;
            dest->is_negative = op1->is_negative;
            return;
        }
    }

    uint64_t digit_shift_count = shift_amt / 64;
    uint64_t leftover_shift_count = shift_amt % 64;

    dest->data.digits = heap::c_allocator.allocate<uint64_t>(op1->digit_count + digit_shift_count + 1);
    dest->digit_count = digit_shift_count;
    uint64_t carry = 0;
    for (size_t i = 0; i < op1->digit_count; i += 1) {
        uint64_t digit = op1_digits[i];
        dest->data.digits[dest->digit_count] = carry | (digit << leftover_shift_count);
        dest->digit_count += 1;
        if (leftover_shift_count > 0) {
            carry = digit >> (64 - leftover_shift_count);
        } else {
            carry = 0;
        }
    }
    dest->data.digits[dest->digit_count] = carry;
    dest->digit_count += 1;
    dest->is_negative = op1->is_negative;
    bigint_normalize(dest);
}

void bigint_shl_trunc(BigInt *dest, const BigInt *op1, const BigInt *op2, size_t bit_count, bool is_signed) {
    BigInt unwrapped = {0};
    bigint_shl(&unwrapped, op1, op2);
    bigint_truncate(dest, &unwrapped, bit_count, is_signed);
}

void bigint_shr(BigInt *dest, const BigInt *op1, const BigInt *op2) {
    assert(!op2->is_negative);

    if (op1->digit_count == 0) {
        return bigint_init_unsigned(dest, 0);
    }

    if (op2->digit_count == 0) {
        return bigint_init_bigint(dest, op1);
    }

    if (op2->digit_count != 1) {
        zig_panic("TODO shift right by amount greater than 64 bit integer");
    }

    const uint64_t *op1_digits = bigint_ptr(op1);
    uint64_t shift_amt = bigint_as_unsigned(op2);

    if (op1->digit_count == 1) {
        dest->data.digit = (shift_amt < 64) ? op1_digits[0] >> shift_amt : 0;
        dest->digit_count = 1;
        dest->is_negative = op1->is_negative;
        bigint_normalize(dest);
        return;
    }

    size_t digit_shift_count = shift_amt / 64;
    size_t leftover_shift_count = shift_amt % 64;

    if (digit_shift_count >= op1->digit_count) {
        return bigint_init_unsigned(dest, 0);
    }

    dest->digit_count = op1->digit_count - digit_shift_count;
    uint64_t *digits;
    if (dest->digit_count == 1) {
        digits = &dest->data.digit;
    } else {
        digits = heap::c_allocator.allocate<uint64_t>(dest->digit_count);
        dest->data.digits = digits;
    }

    uint64_t carry = 0;
    for (size_t op_digit_index = op1->digit_count - 1;;) {
        uint64_t digit = op1_digits[op_digit_index];
        size_t dest_digit_index = op_digit_index - digit_shift_count;
        digits[dest_digit_index] = carry | (digit >> leftover_shift_count);
        carry = (leftover_shift_count != 0) ? (digit << (64 - leftover_shift_count)) : 0;

        if (dest_digit_index == 0) { break; }
        op_digit_index -= 1;
    }
    dest->is_negative = op1->is_negative;
    bigint_normalize(dest);
}

void bigint_negate(BigInt *dest, const BigInt *op) {
    bigint_init_bigint(dest, op);
    dest->is_negative = !dest->is_negative;
    bigint_normalize(dest);
}

void bigint_negate_wrap(BigInt *dest, const BigInt *op, size_t bit_count) {
    BigInt zero;
    bigint_init_unsigned(&zero, 0);
    bigint_sub_wrap(dest, &zero, op, bit_count, true);
}

void bigint_not(BigInt *dest, const BigInt *op, size_t bit_count, bool is_signed) {
    if (bit_count == 0) {
        bigint_init_unsigned(dest, 0);
        return;
    }

    if (is_signed) {
        BigInt twos_comp = {0};
        to_twos_complement(&twos_comp, op, bit_count);

        BigInt inverted = {0};
        bigint_not(&inverted, &twos_comp, bit_count, false);

        from_twos_complement(dest, &inverted, bit_count, true);
        return;
    }

    assert(!op->is_negative);

    dest->is_negative = false;
    const uint64_t *op_digits = bigint_ptr(op);
    if (bit_count <= 64) {
        dest->digit_count = 1;
        if (op->digit_count == 0) {
            if (bit_count == 64) {
                dest->data.digit = UINT64_MAX;
            } else {
                dest->data.digit = (1ULL << bit_count) - 1;
            }
        } else if (op->digit_count == 1) {
            dest->data.digit = ~op_digits[0];
            if (bit_count != 64) {
                uint64_t mask = (1ULL << bit_count) - 1;
                dest->data.digit &= mask;
            }
        }
        bigint_normalize(dest);
        return;
    }
    dest->digit_count = (bit_count + 63) / 64;
    assert(dest->digit_count >= op->digit_count);
    dest->data.digits = heap::c_allocator.allocate_nonzero<uint64_t>(dest->digit_count);
    size_t i = 0;
    for (; i < op->digit_count; i += 1) {
        dest->data.digits[i] = ~op_digits[i];
    }
    for (; i < dest->digit_count; i += 1) {
        dest->data.digits[i] = 0xffffffffffffffffULL;
    }
    size_t digit_index = dest->digit_count - 1;
    size_t digit_bit_index = bit_count % 64;
    if (digit_bit_index != 0) {
        uint64_t mask = (1ULL << digit_bit_index) - 1;
        dest->data.digits[digit_index] &= mask;
    }
    bigint_normalize(dest);
}

void bigint_truncate(BigInt *dest, const BigInt *op, size_t bit_count, bool is_signed) {
    BigInt twos_comp;
    to_twos_complement(&twos_comp, op, bit_count);
    from_twos_complement(dest, &twos_comp, bit_count, is_signed);
}

Cmp bigint_cmp(const BigInt *op1, const BigInt *op2) {
    if (op1->is_negative && !op2->is_negative) {
        return CmpLT;
    } else if (!op1->is_negative && op2->is_negative) {
        return CmpGT;
    } else if (op1->digit_count > op2->digit_count) {
        return op1->is_negative ? CmpLT : CmpGT;
    } else if (op2->digit_count > op1->digit_count) {
        return op1->is_negative ? CmpGT : CmpLT;
    } else if (op1->digit_count == 0) {
        return CmpEQ;
    }
    const uint64_t *op1_digits = bigint_ptr(op1);
    const uint64_t *op2_digits = bigint_ptr(op2);
    for (size_t i = op1->digit_count - 1; ;) {
        uint64_t op1_digit = op1_digits[i];
        uint64_t op2_digit = op2_digits[i];

        if (op1_digit > op2_digit) {
            return op1->is_negative ? CmpLT : CmpGT;
        }
        if (op1_digit < op2_digit) {
            return op1->is_negative ? CmpGT : CmpLT;
        }

        if (i == 0) {
            return CmpEQ;
        }
        i -= 1;
    }
}

void bigint_append_buf(Buf *buf, const BigInt *op, uint64_t base) {
    if (op->digit_count == 0) {
        buf_append_char(buf, '0');
        return;
    }
    if (op->is_negative) {
        buf_append_char(buf, '-');
    }
    if (op->digit_count == 1 && base == 10) {
        buf_appendf(buf, "%" ZIG_PRI_u64, op->data.digit);
        return;
    }
    if (op->digit_count == 1 && base == 16) {
        buf_appendf(buf, "%" ZIG_PRI_x64, op->data.digit);
        return;
    }
    size_t first_digit_index = buf_len(buf);

    BigInt digit_bi = {0};
    BigInt a1 = {0};
    BigInt a2 = {0};

    BigInt *a = &a1;
    BigInt *other_a = &a2;
    bigint_init_bigint(a, op);

    BigInt base_bi = {0};
    bigint_init_unsigned(&base_bi, base);

    for (;;) {
        bigint_rem(&digit_bi, a, &base_bi);
        uint8_t digit = bigint_as_unsigned(&digit_bi);
        buf_append_char(buf, digit_to_char(digit, false));
        bigint_div_trunc(other_a, a, &base_bi);
        {
            BigInt *tmp = a;
            a = other_a;
            other_a = tmp;
        }
        if (bigint_cmp_zero(a) == CmpEQ) {
            break;
        }
    }

    // reverse
    for (size_t i = first_digit_index; i < buf_len(buf) / 2; i += 1) {
        size_t other_i = buf_len(buf) + first_digit_index - i - 1;
        uint8_t tmp = buf_ptr(buf)[i];
        buf_ptr(buf)[i] = buf_ptr(buf)[other_i];
        buf_ptr(buf)[other_i] = tmp;
    }
}

size_t bigint_popcount_unsigned(const BigInt *bi) {
    assert(!bi->is_negative);
    if (bi->digit_count == 0)
        return 0;

    size_t count = 0;
    size_t bit_count = bi->digit_count * 64;
    for (size_t i = 0; i < bit_count; i += 1) {
        if (bit_at_index(bi, i))
            count += 1;
    }
    return count;
}

size_t bigint_popcount_signed(const BigInt *bi, size_t bit_count) {
    if (bit_count == 0)
        return 0;
    if (bi->digit_count == 0)
        return 0;

    BigInt twos_comp = {0};
    to_twos_complement(&twos_comp, bi, bit_count);

    size_t count = 0;
    for (size_t i = 0; i < bit_count; i += 1) {
        if (bit_at_index(&twos_comp, i))
            count += 1;
    }
    return count;
}

size_t bigint_ctz(const BigInt *bi, size_t bit_count) {
    if (bit_count == 0)
        return 0;
    if (bi->digit_count == 0)
        return bit_count;

    BigInt twos_comp = {0};
    to_twos_complement(&twos_comp, bi, bit_count);

    size_t count = 0;
    for (size_t i = 0; i < bit_count; i += 1) {
        if (bit_at_index(&twos_comp, i))
            return count;
        count += 1;
    }
    return count;
}

size_t bigint_clz(const BigInt *bi, size_t bit_count) {
    if (bi->is_negative || bit_count == 0)
        return 0;
    if (bi->digit_count == 0)
        return bit_count;

    size_t count = 0;
    for (size_t i = bit_count - 1;;) {
        if (bit_at_index(bi, i))
            return count;
        count += 1;

        if (i == 0) break;
        i -= 1;
    }
    return count;
}

static uint64_t bigint_as_unsigned(const BigInt *bigint) {
    assert(!bigint->is_negative);
    if (bigint->digit_count == 0) {
        return 0;
    } else if (bigint->digit_count == 1) {
        return bigint->data.digit;
    } else {
        zig_unreachable();
    }
}

uint64_t bigint_as_u64(const BigInt *bigint)
{
    return bigint_as_unsigned(bigint);
}

uint32_t bigint_as_u32(const BigInt *bigint) {
    uint64_t value64 = bigint_as_unsigned(bigint);
    uint32_t value32 = (uint32_t)value64;
    assert (value64 == value32);
    return value32;
}

size_t bigint_as_usize(const BigInt *bigint) {
    uint64_t value64 = bigint_as_unsigned(bigint);
    size_t valueUsize = (size_t)value64;
    assert (value64 == valueUsize);
    return valueUsize;
}

int64_t bigint_as_signed(const BigInt *bigint) {
    if (bigint->digit_count == 0) {
        return 0;
    } else if (bigint->digit_count == 1) {
        if (bigint->is_negative) {
            if (bigint->data.digit <= 9223372036854775808ULL) {
                return (-((int64_t)(bigint->data.digit - 1))) - 1;
            } else {
                zig_unreachable();
            }
        } else {
            return bigint->data.digit;
        }
    } else {
        zig_unreachable();
    }
}

Cmp bigint_cmp_zero(const BigInt *op) {
    if (op->digit_count == 0) {
        return CmpEQ;
    }
    return op->is_negative ? CmpLT : CmpGT;
}

uint32_t bigint_hash(BigInt x) {
    if (x.digit_count == 0) {
        return 0;
    } else {
        return bigint_ptr(&x)[0];
    }
}

bool bigint_eql(BigInt a, BigInt b) {
    return bigint_cmp(&a, &b) == CmpEQ;
}

void bigint_incr(BigInt *x) {
    if (x->digit_count == 0) {
        bigint_init_unsigned(x, 1);
        return;
    }

    if (x->digit_count == 1) {
        if (x->is_negative && x->data.digit != 0) {
            x->data.digit -= 1;
            return;
        } else if (!x->is_negative && x->data.digit != UINT64_MAX) {
            x->data.digit += 1;
            return;
        }
    }

    BigInt copy;
    bigint_init_bigint(&copy, x);

    BigInt one;
    bigint_init_unsigned(&one, 1);

    bigint_add(x, &copy, &one);
}

void bigint_decr(BigInt *x) {
    if (x->digit_count == 0) {
        bigint_init_signed(x, -1);
        return;
    }

    if (x->digit_count == 1) {
        if (x->is_negative && x->data.digit != UINT64_MAX) {
            x->data.digit += 1;
            return;
        } else if (!x->is_negative && x->data.digit != 0) {
            x->data.digit -= 1;
            return;
        }
    }

    BigInt copy;
    bigint_init_bigint(&copy, x);

    BigInt neg_one;
    bigint_init_signed(&neg_one, -1);

    bigint_add(x, &copy, &neg_one);
}
