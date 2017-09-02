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
        return digit + (uppercase ? 'A' : 'a');
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
    dest->data.digits = allocate_nonzero<uint64_t>(dest->digit_count);
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

void bigint_init_u128(BigInt *dest, unsigned __int128 x) {
    uint64_t low = (uint64_t)(x & UINT64_MAX);
    uint64_t high = (uint64_t)(x >> 64);

    if (high == 0) {
        return bigint_init_unsigned(dest, low);
    }

    dest->digit_count = 2;
    dest->data.digits = allocate_nonzero<uint64_t>(2);
    dest->data.digits[0] = low;
    dest->data.digits[1] = high;
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
    dest->data.digits = allocate_nonzero<uint64_t>(digit_count);
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
    dest->data.digits = allocate_nonzero<uint64_t>(dest->digit_count);
    memcpy(dest->data.digits, src->data.digits, sizeof(uint64_t) * dest->digit_count);
}

void bigint_init_bigfloat(BigInt *dest, const BigFloat *op) {
    if (op->value >= 0) {
        bigint_init_u128(dest, (unsigned __int128)(op->value));
    } else {
        bigint_init_u128(dest, (unsigned __int128)(-op->value));
        dest->is_negative = true;
    }
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
        digits = allocate_nonzero<uint64_t>(dest->digit_count);
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

static bool add_u64_overflow(uint64_t op1, uint64_t op2, uint64_t *result) {
    return __builtin_uaddll_overflow((unsigned long long)op1, (unsigned long long)op2,
            (unsigned long long *)result);
}

static bool sub_u64_overflow(uint64_t op1, uint64_t op2, uint64_t *result) {
    return __builtin_usubll_overflow((unsigned long long)op1, (unsigned long long)op2,
            (unsigned long long *)result);
}

static bool mul_u64_overflow(uint64_t op1, uint64_t op2, uint64_t *result) {
    return __builtin_umulll_overflow((unsigned long long)op1, (unsigned long long)op2,
            (unsigned long long *)result);
}

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
        uint64_t overflow = add_u64_overflow(op1_digits[0], op2_digits[0], &dest->data.digit);
        if (overflow == 0 && op1->digit_count == 1 && op2->digit_count == 1) {
            dest->digit_count = 1;
            bigint_normalize(dest);
            return;
        }
        size_t i = 1;
        uint64_t first_digit = dest->data.digit;
        dest->data.digits = allocate_nonzero<uint64_t>(max(op1->digit_count, op2->digit_count) + 1);
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
    dest->data.digits = allocate_nonzero<uint64_t>(bigger_op->digit_count);
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

        if (!found_digit)
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

static void mul_overflow(uint64_t x, uint64_t y, uint64_t *result, uint64_t *carry) {
    if (!mul_u64_overflow(x, y, result)) {
        *carry = 0;
        return;
    }

    unsigned __int128 big_x = x;
    unsigned __int128 big_y = y;
    unsigned __int128 big_result = big_x * big_y;
    *carry = big_result >> 64;
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

void bigint_div_trunc(BigInt *dest, const BigInt *op1, const BigInt *op2) {
    assert(op2->digit_count != 0); // division by zero
    if (op1->digit_count == 0) {
        bigint_init_unsigned(dest, 0);
        return;
    }
    if (op1->digit_count != 1 || op2->digit_count != 1) {
        zig_panic("TODO bigint div_trunc with >1 digits");
    }
    const uint64_t *op1_digits = bigint_ptr(op1);
    const uint64_t *op2_digits = bigint_ptr(op2);
    dest->data.digit = op1_digits[0] / op2_digits[0];
    dest->digit_count = 1;
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
    if (op2->digit_count == 2 && op2_digits[0] == 0 && op2_digits[1] == 1) {
        // special case this divisor
        bigint_init_unsigned(dest, op1_digits[0]);
        dest->is_negative = op1->is_negative;
        bigint_normalize(dest);
        return;
    }
    if (op1->digit_count != 1 || op2->digit_count != 1) {
        zig_panic("TODO bigint rem with >1 digits");
    }
    dest->data.digit = op1_digits[0] % op2_digits[0];
    dest->digit_count = 1;
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
        // TODO this code path is untested
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
        // TODO this code path is untested
        uint64_t first_digit = dest->data.digit;
        dest->digit_count = max(op1->digit_count, op2->digit_count);
        dest->data.digits = allocate_nonzero<uint64_t>(dest->digit_count);
        dest->data.digits[0] = first_digit;
        size_t i = 1;
        for (; i < dest->digit_count; i += 1) {
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
        // TODO this code path is untested
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
        // TODO this code path is untested
        uint64_t first_digit = dest->data.digit;
        dest->digit_count = max(op1->digit_count, op2->digit_count);
        dest->data.digits = allocate_nonzero<uint64_t>(dest->digit_count);
        dest->data.digits[0] = first_digit;
        size_t i = 1;
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
    if (op1->is_negative || op2->is_negative) {
        // TODO this code path is untested
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
        if (op1->digit_count == 1 && op2->digit_count == 1) {
            dest->digit_count = 1;
            dest->data.digit = op1_digits[0] ^ op2_digits[0];
            bigint_normalize(dest);
            return;
        }
        // TODO this code path is untested
        uint64_t first_digit = dest->data.digit;
        dest->digit_count = max(op1->digit_count, op2->digit_count);
        dest->data.digits = allocate_nonzero<uint64_t>(dest->digit_count);
        dest->data.digits[0] = first_digit;
        size_t i = 1;
        for (; i < op1->digit_count && i < op2->digit_count; i += 1) {
            dest->data.digits[i] = op1_digits[i] ^ op2_digits[i];
        }
        for (; i < dest->digit_count; i += 1) {
            if (i < op1->digit_count) {
                dest->data.digits[i] = op1_digits[i];
            }
            if (i < op2->digit_count) {
                dest->data.digits[i] = op2_digits[i];
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

    dest->data.digits = allocate<uint64_t>(op1->digit_count + digit_shift_count + 1);
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
        dest->data.digit = op1_digits[0] >> shift_amt;
        dest->digit_count = 1;
        dest->is_negative = op1->is_negative;
        bigint_normalize(dest);
        return;
    }

    // TODO this code path is untested
    size_t digit_shift_count = shift_amt / 64;
    size_t leftover_shift_count = shift_amt % 64;

    if (digit_shift_count >= op1->digit_count) {
        return bigint_init_unsigned(dest, 0);
    }

    dest->digit_count = op1->digit_count - digit_shift_count;
    dest->data.digits = allocate<uint64_t>(dest->digit_count);
    uint64_t carry = 0;
    for (size_t op_digit_index = op1->digit_count - 1;;) {
        uint64_t digit = op1_digits[op_digit_index];
        size_t dest_digit_index = op_digit_index - digit_shift_count;
        dest->data.digits[dest_digit_index] = carry | (digit >> leftover_shift_count);
        carry = (0xffffffffffffffffULL << leftover_shift_count) & digit;

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
    // TODO this code path is untested
    dest->digit_count = bit_count / 64;
    assert(dest->digit_count >= op->digit_count);
    dest->data.digits = allocate_nonzero<uint64_t>(dest->digit_count);
    size_t i = 0;
    for (; i < op->digit_count; i += 1) {
        dest->data.digits[i] = ~op_digits[i];
    }
    for (; i < dest->digit_count; i += 1) {
        dest->data.digits[i] = 0xffffffffffffffffULL;
    }
    size_t digit_index = dest->digit_count - (bit_count / 64) - 1;
    size_t digit_bit_index = bit_count % 64;
    if (digit_index < dest->digit_count) {
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
    // TODO this code path is untested
    size_t first_digit_index = buf_len(buf);

    BigInt digit_bi = {0};
    BigInt a1 = {0};
    BigInt a2 = {0};

    BigInt *a = &a1;
    BigInt *other_a = &a2;
    bigint_init_bigint(a, op);

    BigInt base_bi = {0};
    bigint_init_unsigned(&base_bi, 10);

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
    for (size_t i = first_digit_index; i < buf_len(buf); i += 1) {
        size_t other_i = buf_len(buf) + first_digit_index - i - 1;
        uint8_t tmp = buf_ptr(buf)[i];
        buf_ptr(buf)[i] = buf_ptr(buf)[other_i];
        buf_ptr(buf)[other_i] = tmp;
    }
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

uint64_t bigint_as_unsigned(const BigInt *bigint) {
    assert(!bigint->is_negative);
    if (bigint->digit_count == 0) {
        return 0;
    } else if (bigint->digit_count == 1) {
        return bigint->data.digit;
    } else {
        zig_unreachable();
    }
}

int64_t bigint_as_signed(const BigInt *bigint) {
    if (bigint->digit_count == 0) {
        return 0;
    } else if (bigint->digit_count == 1) {
        if (bigint->is_negative) {
            // TODO this code path is untested
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
