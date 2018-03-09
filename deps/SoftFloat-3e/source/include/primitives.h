
/*============================================================================

This C header file is part of the SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3e, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014, 2015, 2016, 2017 The Regents of the
University of California.  All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice,
    this list of conditions, and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions, and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

 3. Neither the name of the University nor the names of its contributors may
    be used to endorse or promote products derived from this software without
    specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS "AS IS", AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, ARE
DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=============================================================================*/

#ifndef primitives_h
#define primitives_h 1

#include <stdbool.h>
#include <stdint.h>
#include "primitiveTypes.h"

#ifndef softfloat_shortShiftRightJam64
/*----------------------------------------------------------------------------
| Shifts 'a' right by the number of bits given in 'dist', which must be in
| the range 1 to 63.  If any nonzero bits are shifted off, they are "jammed"
| into the least-significant bit of the shifted value by setting the least-
| significant bit to 1.  This shifted-and-jammed value is returned.
*----------------------------------------------------------------------------*/
#if defined INLINE_LEVEL && (2 <= INLINE_LEVEL)
INLINE
uint64_t softfloat_shortShiftRightJam64( uint64_t a, uint_fast8_t dist )
    { return a>>dist | ((a & (((uint_fast64_t) 1<<dist) - 1)) != 0); }
#else
uint64_t softfloat_shortShiftRightJam64( uint64_t a, uint_fast8_t dist );
#endif
#endif

#ifndef softfloat_shiftRightJam32
/*----------------------------------------------------------------------------
| Shifts 'a' right by the number of bits given in 'dist', which must not
| be zero.  If any nonzero bits are shifted off, they are "jammed" into the
| least-significant bit of the shifted value by setting the least-significant
| bit to 1.  This shifted-and-jammed value is returned.
|   The value of 'dist' can be arbitrarily large.  In particular, if 'dist' is
| greater than 32, the result will be either 0 or 1, depending on whether 'a'
| is zero or nonzero.
*----------------------------------------------------------------------------*/
#if defined INLINE_LEVEL && (2 <= INLINE_LEVEL)
INLINE uint32_t softfloat_shiftRightJam32( uint32_t a, uint_fast16_t dist )
{
    return
        (dist < 31) ? a>>dist | ((uint32_t) (a<<(-dist & 31)) != 0) : (a != 0);
}
#else
uint32_t softfloat_shiftRightJam32( uint32_t a, uint_fast16_t dist );
#endif
#endif

#ifndef softfloat_shiftRightJam64
/*----------------------------------------------------------------------------
| Shifts 'a' right by the number of bits given in 'dist', which must not
| be zero.  If any nonzero bits are shifted off, they are "jammed" into the
| least-significant bit of the shifted value by setting the least-significant
| bit to 1.  This shifted-and-jammed value is returned.
|   The value of 'dist' can be arbitrarily large.  In particular, if 'dist' is
| greater than 64, the result will be either 0 or 1, depending on whether 'a'
| is zero or nonzero.
*----------------------------------------------------------------------------*/
#if defined INLINE_LEVEL && (3 <= INLINE_LEVEL)
INLINE uint64_t softfloat_shiftRightJam64( uint64_t a, uint_fast32_t dist )
{
    return
        (dist < 63) ? a>>dist | ((uint64_t) (a<<(-dist & 63)) != 0) : (a != 0);
}
#else
uint64_t softfloat_shiftRightJam64( uint64_t a, uint_fast32_t dist );
#endif
#endif

/*----------------------------------------------------------------------------
| A constant table that translates an 8-bit unsigned integer (the array index)
| into the number of leading 0 bits before the most-significant 1 of that
| integer.  For integer zero (index 0), the corresponding table element is 8.
*----------------------------------------------------------------------------*/
extern const uint_least8_t softfloat_countLeadingZeros8[256];

#ifndef softfloat_countLeadingZeros16
/*----------------------------------------------------------------------------
| Returns the number of leading 0 bits before the most-significant 1 bit of
| 'a'.  If 'a' is zero, 16 is returned.
*----------------------------------------------------------------------------*/
#if defined INLINE_LEVEL && (2 <= INLINE_LEVEL)
INLINE uint_fast8_t softfloat_countLeadingZeros16( uint16_t a )
{
    uint_fast8_t count = 8;
    if ( 0x100 <= a ) {
        count = 0;
        a >>= 8;
    }
    count += softfloat_countLeadingZeros8[a];
    return count;
}
#else
uint_fast8_t softfloat_countLeadingZeros16( uint16_t a );
#endif
#endif

#ifndef softfloat_countLeadingZeros32
/*----------------------------------------------------------------------------
| Returns the number of leading 0 bits before the most-significant 1 bit of
| 'a'.  If 'a' is zero, 32 is returned.
*----------------------------------------------------------------------------*/
#if defined INLINE_LEVEL && (3 <= INLINE_LEVEL)
INLINE uint_fast8_t softfloat_countLeadingZeros32( uint32_t a )
{
    uint_fast8_t count = 0;
    if ( a < 0x10000 ) {
        count = 16;
        a <<= 16;
    }
    if ( a < 0x1000000 ) {
        count += 8;
        a <<= 8;
    }
    count += softfloat_countLeadingZeros8[a>>24];
    return count;
}
#else
uint_fast8_t softfloat_countLeadingZeros32( uint32_t a );
#endif
#endif

#ifndef softfloat_countLeadingZeros64
/*----------------------------------------------------------------------------
| Returns the number of leading 0 bits before the most-significant 1 bit of
| 'a'.  If 'a' is zero, 64 is returned.
*----------------------------------------------------------------------------*/
uint_fast8_t softfloat_countLeadingZeros64( uint64_t a );
#endif

extern const uint16_t softfloat_approxRecip_1k0s[16];
extern const uint16_t softfloat_approxRecip_1k1s[16];

#ifndef softfloat_approxRecip32_1
/*----------------------------------------------------------------------------
| Returns an approximation to the reciprocal of the number represented by 'a',
| where 'a' is interpreted as an unsigned fixed-point number with one integer
| bit and 31 fraction bits.  The 'a' input must be "normalized", meaning that
| its most-significant bit (bit 31) must be 1.  Thus, if A is the value of
| the fixed-point interpretation of 'a', then 1 <= A < 2.  The returned value
| is interpreted as a pure unsigned fraction, having no integer bits and 32
| fraction bits.  The approximation returned is never greater than the true
| reciprocal 1/A, and it differs from the true reciprocal by at most 2.006 ulp
| (units in the last place).
*----------------------------------------------------------------------------*/
#ifdef SOFTFLOAT_FAST_DIV64TO32
#define softfloat_approxRecip32_1( a ) ((uint32_t) (UINT64_C( 0x7FFFFFFFFFFFFFFF ) / (uint32_t) (a)))
#else
uint32_t softfloat_approxRecip32_1( uint32_t a );
#endif
#endif

extern const uint16_t softfloat_approxRecipSqrt_1k0s[16];
extern const uint16_t softfloat_approxRecipSqrt_1k1s[16];

#ifndef softfloat_approxRecipSqrt32_1
/*----------------------------------------------------------------------------
| Returns an approximation to the reciprocal of the square root of the number
| represented by 'a', where 'a' is interpreted as an unsigned fixed-point
| number either with one integer bit and 31 fraction bits or with two integer
| bits and 30 fraction bits.  The format of 'a' is determined by 'oddExpA',
| which must be either 0 or 1.  If 'oddExpA' is 1, 'a' is interpreted as
| having one integer bit, and if 'oddExpA' is 0, 'a' is interpreted as having
| two integer bits.  The 'a' input must be "normalized", meaning that its
| most-significant bit (bit 31) must be 1.  Thus, if A is the value of the
| fixed-point interpretation of 'a', it follows that 1 <= A < 2 when 'oddExpA'
| is 1, and 2 <= A < 4 when 'oddExpA' is 0.
|   The returned value is interpreted as a pure unsigned fraction, having
| no integer bits and 32 fraction bits.  The approximation returned is never
| greater than the true reciprocal 1/sqrt(A), and it differs from the true
| reciprocal by at most 2.06 ulp (units in the last place).  The approximation
| returned is also always within the range 0.5 to 1; thus, the most-
| significant bit of the result is always set.
*----------------------------------------------------------------------------*/
uint32_t softfloat_approxRecipSqrt32_1( unsigned int oddExpA, uint32_t a );
#endif

#ifdef SOFTFLOAT_FAST_INT64

/*----------------------------------------------------------------------------
| The following functions are needed only when 'SOFTFLOAT_FAST_INT64' is
| defined.
*----------------------------------------------------------------------------*/

#ifndef softfloat_eq128
/*----------------------------------------------------------------------------
| Returns true if the 128-bit unsigned integer formed by concatenating 'a64'
| and 'a0' is equal to the 128-bit unsigned integer formed by concatenating
| 'b64' and 'b0'.
*----------------------------------------------------------------------------*/
#if defined INLINE_LEVEL && (1 <= INLINE_LEVEL)
INLINE
bool softfloat_eq128( uint64_t a64, uint64_t a0, uint64_t b64, uint64_t b0 )
    { return (a64 == b64) && (a0 == b0); }
#else
bool softfloat_eq128( uint64_t a64, uint64_t a0, uint64_t b64, uint64_t b0 );
#endif
#endif

#ifndef softfloat_le128
/*----------------------------------------------------------------------------
| Returns true if the 128-bit unsigned integer formed by concatenating 'a64'
| and 'a0' is less than or equal to the 128-bit unsigned integer formed by
| concatenating 'b64' and 'b0'.
*----------------------------------------------------------------------------*/
#if defined INLINE_LEVEL && (2 <= INLINE_LEVEL)
INLINE
bool softfloat_le128( uint64_t a64, uint64_t a0, uint64_t b64, uint64_t b0 )
    { return (a64 < b64) || ((a64 == b64) && (a0 <= b0)); }
#else
bool softfloat_le128( uint64_t a64, uint64_t a0, uint64_t b64, uint64_t b0 );
#endif
#endif

#ifndef softfloat_lt128
/*----------------------------------------------------------------------------
| Returns true if the 128-bit unsigned integer formed by concatenating 'a64'
| and 'a0' is less than the 128-bit unsigned integer formed by concatenating
| 'b64' and 'b0'.
*----------------------------------------------------------------------------*/
#if defined INLINE_LEVEL && (2 <= INLINE_LEVEL)
INLINE
bool softfloat_lt128( uint64_t a64, uint64_t a0, uint64_t b64, uint64_t b0 )
    { return (a64 < b64) || ((a64 == b64) && (a0 < b0)); }
#else
bool softfloat_lt128( uint64_t a64, uint64_t a0, uint64_t b64, uint64_t b0 );
#endif
#endif

#ifndef softfloat_shortShiftLeft128
/*----------------------------------------------------------------------------
| Shifts the 128 bits formed by concatenating 'a64' and 'a0' left by the
| number of bits given in 'dist', which must be in the range 1 to 63.
*----------------------------------------------------------------------------*/
#if defined INLINE_LEVEL && (2 <= INLINE_LEVEL)
INLINE
struct uint128
 softfloat_shortShiftLeft128( uint64_t a64, uint64_t a0, uint_fast8_t dist )
{
    struct uint128 z;
    z.v64 = a64<<dist | a0>>(-dist & 63);
    z.v0 = a0<<dist;
    return z;
}
#else
struct uint128
 softfloat_shortShiftLeft128( uint64_t a64, uint64_t a0, uint_fast8_t dist );
#endif
#endif

#ifndef softfloat_shortShiftRight128
/*----------------------------------------------------------------------------
| Shifts the 128 bits formed by concatenating 'a64' and 'a0' right by the
| number of bits given in 'dist', which must be in the range 1 to 63.
*----------------------------------------------------------------------------*/
#if defined INLINE_LEVEL && (2 <= INLINE_LEVEL)
INLINE
struct uint128
 softfloat_shortShiftRight128( uint64_t a64, uint64_t a0, uint_fast8_t dist )
{
    struct uint128 z;
    z.v64 = a64>>dist;
    z.v0 = a64<<(-dist & 63) | a0>>dist;
    return z;
}
#else
struct uint128
 softfloat_shortShiftRight128( uint64_t a64, uint64_t a0, uint_fast8_t dist );
#endif
#endif

#ifndef softfloat_shortShiftRightJam64Extra
/*----------------------------------------------------------------------------
| This function is the same as 'softfloat_shiftRightJam64Extra' (below),
| except that 'dist' must be in the range 1 to 63.
*----------------------------------------------------------------------------*/
#if defined INLINE_LEVEL && (2 <= INLINE_LEVEL)
INLINE
struct uint64_extra
 softfloat_shortShiftRightJam64Extra(
     uint64_t a, uint64_t extra, uint_fast8_t dist )
{
    struct uint64_extra z;
    z.v = a>>dist;
    z.extra = a<<(-dist & 63) | (extra != 0);
    return z;
}
#else
struct uint64_extra
 softfloat_shortShiftRightJam64Extra(
     uint64_t a, uint64_t extra, uint_fast8_t dist );
#endif
#endif

#ifndef softfloat_shortShiftRightJam128
/*----------------------------------------------------------------------------
| Shifts the 128 bits formed by concatenating 'a64' and 'a0' right by the
| number of bits given in 'dist', which must be in the range 1 to 63.  If any
| nonzero bits are shifted off, they are "jammed" into the least-significant
| bit of the shifted value by setting the least-significant bit to 1.  This
| shifted-and-jammed value is returned.
*----------------------------------------------------------------------------*/
#if defined INLINE_LEVEL && (3 <= INLINE_LEVEL)
INLINE
struct uint128
 softfloat_shortShiftRightJam128(
     uint64_t a64, uint64_t a0, uint_fast8_t dist )
{
    uint_fast8_t negDist = -dist;
    struct uint128 z;
    z.v64 = a64>>dist;
    z.v0 =
        a64<<(negDist & 63) | a0>>dist
            | ((uint64_t) (a0<<(negDist & 63)) != 0);
    return z;
}
#else
struct uint128
 softfloat_shortShiftRightJam128(
     uint64_t a64, uint64_t a0, uint_fast8_t dist );
#endif
#endif

#ifndef softfloat_shortShiftRightJam128Extra
/*----------------------------------------------------------------------------
| This function is the same as 'softfloat_shiftRightJam128Extra' (below),
| except that 'dist' must be in the range 1 to 63.
*----------------------------------------------------------------------------*/
#if defined INLINE_LEVEL && (3 <= INLINE_LEVEL)
INLINE
struct uint128_extra
 softfloat_shortShiftRightJam128Extra(
     uint64_t a64, uint64_t a0, uint64_t extra, uint_fast8_t dist )
{
    uint_fast8_t negDist = -dist;
    struct uint128_extra z;
    z.v.v64 = a64>>dist;
    z.v.v0 = a64<<(negDist & 63) | a0>>dist;
    z.extra = a0<<(negDist & 63) | (extra != 0);
    return z;
}
#else
struct uint128_extra
 softfloat_shortShiftRightJam128Extra(
     uint64_t a64, uint64_t a0, uint64_t extra, uint_fast8_t dist );
#endif
#endif

#ifndef softfloat_shiftRightJam64Extra
/*----------------------------------------------------------------------------
| Shifts the 128 bits formed by concatenating 'a' and 'extra' right by 64
| _plus_ the number of bits given in 'dist', which must not be zero.  This
| shifted value is at most 64 nonzero bits and is returned in the 'v' field
| of the 'struct uint64_extra' result.  The 64-bit 'extra' field of the result
| contains a value formed as follows from the bits that were shifted off:  The
| _last_ bit shifted off is the most-significant bit of the 'extra' field, and
| the other 63 bits of the 'extra' field are all zero if and only if _all_but_
| _the_last_ bits shifted off were all zero.
|   (This function makes more sense if 'a' and 'extra' are considered to form
| an unsigned fixed-point number with binary point between 'a' and 'extra'.
| This fixed-point value is shifted right by the number of bits given in
| 'dist', and the integer part of this shifted value is returned in the 'v'
| field of the result.  The fractional part of the shifted value is modified
| as described above and returned in the 'extra' field of the result.)
*----------------------------------------------------------------------------*/
#if defined INLINE_LEVEL && (4 <= INLINE_LEVEL)
INLINE
struct uint64_extra
 softfloat_shiftRightJam64Extra(
     uint64_t a, uint64_t extra, uint_fast32_t dist )
{
    struct uint64_extra z;
    if ( dist < 64 ) {
        z.v = a>>dist;
        z.extra = a<<(-dist & 63);
    } else {
        z.v = 0;
        z.extra = (dist == 64) ? a : (a != 0);
    }
    z.extra |= (extra != 0);
    return z;
}
#else
struct uint64_extra
 softfloat_shiftRightJam64Extra(
     uint64_t a, uint64_t extra, uint_fast32_t dist );
#endif
#endif

#ifndef softfloat_shiftRightJam128
/*----------------------------------------------------------------------------
| Shifts the 128 bits formed by concatenating 'a64' and 'a0' right by the
| number of bits given in 'dist', which must not be zero.  If any nonzero bits
| are shifted off, they are "jammed" into the least-significant bit of the
| shifted value by setting the least-significant bit to 1.  This shifted-and-
| jammed value is returned.
|   The value of 'dist' can be arbitrarily large.  In particular, if 'dist' is
| greater than 128, the result will be either 0 or 1, depending on whether the
| original 128 bits are all zeros.
*----------------------------------------------------------------------------*/
struct uint128
 softfloat_shiftRightJam128( uint64_t a64, uint64_t a0, uint_fast32_t dist );
#endif

#ifndef softfloat_shiftRightJam128Extra
/*----------------------------------------------------------------------------
| Shifts the 192 bits formed by concatenating 'a64', 'a0', and 'extra' right
| by 64 _plus_ the number of bits given in 'dist', which must not be zero.
| This shifted value is at most 128 nonzero bits and is returned in the 'v'
| field of the 'struct uint128_extra' result.  The 64-bit 'extra' field of the
| result contains a value formed as follows from the bits that were shifted
| off:  The _last_ bit shifted off is the most-significant bit of the 'extra'
| field, and the other 63 bits of the 'extra' field are all zero if and only
| if _all_but_the_last_ bits shifted off were all zero.
|   (This function makes more sense if 'a64', 'a0', and 'extra' are considered
| to form an unsigned fixed-point number with binary point between 'a0' and
| 'extra'.  This fixed-point value is shifted right by the number of bits
| given in 'dist', and the integer part of this shifted value is returned
| in the 'v' field of the result.  The fractional part of the shifted value
| is modified as described above and returned in the 'extra' field of the
| result.)
*----------------------------------------------------------------------------*/
struct uint128_extra
 softfloat_shiftRightJam128Extra(
     uint64_t a64, uint64_t a0, uint64_t extra, uint_fast32_t dist );
#endif

#ifndef softfloat_shiftRightJam256M
/*----------------------------------------------------------------------------
| Shifts the 256-bit unsigned integer pointed to by 'aPtr' right by the number
| of bits given in 'dist', which must not be zero.  If any nonzero bits are
| shifted off, they are "jammed" into the least-significant bit of the shifted
| value by setting the least-significant bit to 1.  This shifted-and-jammed
| value is stored at the location pointed to by 'zPtr'.  Each of 'aPtr' and
| 'zPtr' points to an array of four 64-bit elements that concatenate in the
| platform's normal endian order to form a 256-bit integer.
|   The value of 'dist' can be arbitrarily large.  In particular, if 'dist'
| is greater than 256, the stored result will be either 0 or 1, depending on
| whether the original 256 bits are all zeros.
*----------------------------------------------------------------------------*/
void
 softfloat_shiftRightJam256M(
     const uint64_t *aPtr, uint_fast32_t dist, uint64_t *zPtr );
#endif

#ifndef softfloat_add128
/*----------------------------------------------------------------------------
| Returns the sum of the 128-bit integer formed by concatenating 'a64' and
| 'a0' and the 128-bit integer formed by concatenating 'b64' and 'b0'.  The
| addition is modulo 2^128, so any carry out is lost.
*----------------------------------------------------------------------------*/
#if defined INLINE_LEVEL && (2 <= INLINE_LEVEL)
INLINE
struct uint128
 softfloat_add128( uint64_t a64, uint64_t a0, uint64_t b64, uint64_t b0 )
{
    struct uint128 z;
    z.v0 = a0 + b0;
    z.v64 = a64 + b64 + (z.v0 < a0);
    return z;
}
#else
struct uint128
 softfloat_add128( uint64_t a64, uint64_t a0, uint64_t b64, uint64_t b0 );
#endif
#endif

#ifndef softfloat_add256M
/*----------------------------------------------------------------------------
| Adds the two 256-bit integers pointed to by 'aPtr' and 'bPtr'.  The addition
| is modulo 2^256, so any carry out is lost.  The sum is stored at the
| location pointed to by 'zPtr'.  Each of 'aPtr', 'bPtr', and 'zPtr' points to
| an array of four 64-bit elements that concatenate in the platform's normal
| endian order to form a 256-bit integer.
*----------------------------------------------------------------------------*/
void
 softfloat_add256M(
     const uint64_t *aPtr, const uint64_t *bPtr, uint64_t *zPtr );
#endif

#ifndef softfloat_sub128
/*----------------------------------------------------------------------------
| Returns the difference of the 128-bit integer formed by concatenating 'a64'
| and 'a0' and the 128-bit integer formed by concatenating 'b64' and 'b0'.
| The subtraction is modulo 2^128, so any borrow out (carry out) is lost.
*----------------------------------------------------------------------------*/
#if defined INLINE_LEVEL && (2 <= INLINE_LEVEL)
INLINE
struct uint128
 softfloat_sub128( uint64_t a64, uint64_t a0, uint64_t b64, uint64_t b0 )
{
    struct uint128 z;
    z.v0 = a0 - b0;
    z.v64 = a64 - b64;
    z.v64 -= (a0 < b0);
    return z;
}
#else
struct uint128
 softfloat_sub128( uint64_t a64, uint64_t a0, uint64_t b64, uint64_t b0 );
#endif
#endif

#ifndef softfloat_sub256M
/*----------------------------------------------------------------------------
| Subtracts the 256-bit integer pointed to by 'bPtr' from the 256-bit integer
| pointed to by 'aPtr'.  The addition is modulo 2^256, so any borrow out
| (carry out) is lost.  The difference is stored at the location pointed to
| by 'zPtr'.  Each of 'aPtr', 'bPtr', and 'zPtr' points to an array of four
| 64-bit elements that concatenate in the platform's normal endian order to
| form a 256-bit integer.
*----------------------------------------------------------------------------*/
void
 softfloat_sub256M(
     const uint64_t *aPtr, const uint64_t *bPtr, uint64_t *zPtr );
#endif

#ifndef softfloat_mul64ByShifted32To128
/*----------------------------------------------------------------------------
| Returns the 128-bit product of 'a', 'b', and 2^32.
*----------------------------------------------------------------------------*/
#if defined INLINE_LEVEL && (3 <= INLINE_LEVEL)
INLINE struct uint128 softfloat_mul64ByShifted32To128( uint64_t a, uint32_t b )
{
    uint_fast64_t mid;
    struct uint128 z;
    mid = (uint_fast64_t) (uint32_t) a * b;
    z.v0 = mid<<32;
    z.v64 = (uint_fast64_t) (uint32_t) (a>>32) * b + (mid>>32);
    return z;
}
#else
struct uint128 softfloat_mul64ByShifted32To128( uint64_t a, uint32_t b );
#endif
#endif

#ifndef softfloat_mul64To128
/*----------------------------------------------------------------------------
| Returns the 128-bit product of 'a' and 'b'.
*----------------------------------------------------------------------------*/
struct uint128 softfloat_mul64To128( uint64_t a, uint64_t b );
#endif

#ifndef softfloat_mul128By32
/*----------------------------------------------------------------------------
| Returns the product of the 128-bit integer formed by concatenating 'a64' and
| 'a0', multiplied by 'b'.  The multiplication is modulo 2^128; any overflow
| bits are discarded.
*----------------------------------------------------------------------------*/
#if defined INLINE_LEVEL && (4 <= INLINE_LEVEL)
INLINE
struct uint128 softfloat_mul128By32( uint64_t a64, uint64_t a0, uint32_t b )
{
    struct uint128 z;
    uint_fast64_t mid;
    uint_fast32_t carry;
    z.v0 = a0 * b;
    mid = (uint_fast64_t) (uint32_t) (a0>>32) * b;
    carry = (uint32_t) ((uint_fast32_t) (z.v0>>32) - (uint_fast32_t) mid);
    z.v64 = a64 * b + (uint_fast32_t) ((mid + carry)>>32);
    return z;
}
#else
struct uint128 softfloat_mul128By32( uint64_t a64, uint64_t a0, uint32_t b );
#endif
#endif

#ifndef softfloat_mul128To256M
/*----------------------------------------------------------------------------
| Multiplies the 128-bit unsigned integer formed by concatenating 'a64' and
| 'a0' by the 128-bit unsigned integer formed by concatenating 'b64' and
| 'b0'.  The 256-bit product is stored at the location pointed to by 'zPtr'.
| Argument 'zPtr' points to an array of four 64-bit elements that concatenate
| in the platform's normal endian order to form a 256-bit integer.
*----------------------------------------------------------------------------*/
void
 softfloat_mul128To256M(
     uint64_t a64, uint64_t a0, uint64_t b64, uint64_t b0, uint64_t *zPtr );
#endif

#else

/*----------------------------------------------------------------------------
| The following functions are needed only when 'SOFTFLOAT_FAST_INT64' is not
| defined.
*----------------------------------------------------------------------------*/

#ifndef softfloat_compare96M
/*----------------------------------------------------------------------------
| Compares the two 96-bit unsigned integers pointed to by 'aPtr' and 'bPtr'.
| Returns -1 if the first integer (A) is less than the second (B); returns 0
| if the two integers are equal; and returns +1 if the first integer (A)
| is greater than the second (B).  (The result is thus the signum of A - B.)
| Each of 'aPtr' and 'bPtr' points to an array of three 32-bit elements that
| concatenate in the platform's normal endian order to form a 96-bit integer.
*----------------------------------------------------------------------------*/
int_fast8_t softfloat_compare96M( const uint32_t *aPtr, const uint32_t *bPtr );
#endif

#ifndef softfloat_compare128M
/*----------------------------------------------------------------------------
| Compares the two 128-bit unsigned integers pointed to by 'aPtr' and 'bPtr'.
| Returns -1 if the first integer (A) is less than the second (B); returns 0
| if the two integers are equal; and returns +1 if the first integer (A)
| is greater than the second (B).  (The result is thus the signum of A - B.)
| Each of 'aPtr' and 'bPtr' points to an array of four 32-bit elements that
| concatenate in the platform's normal endian order to form a 128-bit integer.
*----------------------------------------------------------------------------*/
int_fast8_t
 softfloat_compare128M( const uint32_t *aPtr, const uint32_t *bPtr );
#endif

#ifndef softfloat_shortShiftLeft64To96M
/*----------------------------------------------------------------------------
| Extends 'a' to 96 bits and shifts the value left by the number of bits given
| in 'dist', which must be in the range 1 to 31.  The result is stored at the
| location pointed to by 'zPtr'.  Argument 'zPtr' points to an array of three
| 32-bit elements that concatenate in the platform's normal endian order to
| form a 96-bit integer.
*----------------------------------------------------------------------------*/
#if defined INLINE_LEVEL && (2 <= INLINE_LEVEL)
INLINE
void
 softfloat_shortShiftLeft64To96M(
     uint64_t a, uint_fast8_t dist, uint32_t *zPtr )
{
    zPtr[indexWord( 3, 0 )] = (uint32_t) a<<dist;
    a >>= 32 - dist;
    zPtr[indexWord( 3, 2 )] = a>>32;
    zPtr[indexWord( 3, 1 )] = a;
}
#else
void
 softfloat_shortShiftLeft64To96M(
     uint64_t a, uint_fast8_t dist, uint32_t *zPtr );
#endif
#endif

#ifndef softfloat_shortShiftLeftM
/*----------------------------------------------------------------------------
| Shifts the N-bit unsigned integer pointed to by 'aPtr' left by the number
| of bits given in 'dist', where N = 'size_words' * 32.  The value of 'dist'
| must be in the range 1 to 31.  Any nonzero bits shifted off are lost.  The
| shifted N-bit result is stored at the location pointed to by 'zPtr'.  Each
| of 'aPtr' and 'zPtr' points to a 'size_words'-long array of 32-bit elements
| that concatenate in the platform's normal endian order to form an N-bit
| integer.
*----------------------------------------------------------------------------*/
void
 softfloat_shortShiftLeftM(
     uint_fast8_t size_words,
     const uint32_t *aPtr,
     uint_fast8_t dist,
     uint32_t *zPtr
 );
#endif

#ifndef softfloat_shortShiftLeft96M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_shortShiftLeftM' with
| 'size_words' = 3 (N = 96).
*----------------------------------------------------------------------------*/
#define softfloat_shortShiftLeft96M( aPtr, dist, zPtr ) softfloat_shortShiftLeftM( 3, aPtr, dist, zPtr )
#endif

#ifndef softfloat_shortShiftLeft128M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_shortShiftLeftM' with
| 'size_words' = 4 (N = 128).
*----------------------------------------------------------------------------*/
#define softfloat_shortShiftLeft128M( aPtr, dist, zPtr ) softfloat_shortShiftLeftM( 4, aPtr, dist, zPtr )
#endif

#ifndef softfloat_shortShiftLeft160M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_shortShiftLeftM' with
| 'size_words' = 5 (N = 160).
*----------------------------------------------------------------------------*/
#define softfloat_shortShiftLeft160M( aPtr, dist, zPtr ) softfloat_shortShiftLeftM( 5, aPtr, dist, zPtr )
#endif

#ifndef softfloat_shiftLeftM
/*----------------------------------------------------------------------------
| Shifts the N-bit unsigned integer pointed to by 'aPtr' left by the number
| of bits given in 'dist', where N = 'size_words' * 32.  The value of 'dist'
| must not be zero.  Any nonzero bits shifted off are lost.  The shifted
| N-bit result is stored at the location pointed to by 'zPtr'.  Each of 'aPtr'
| and 'zPtr' points to a 'size_words'-long array of 32-bit elements that
| concatenate in the platform's normal endian order to form an N-bit integer.
|   The value of 'dist' can be arbitrarily large.  In particular, if 'dist' is
| greater than N, the stored result will be 0.
*----------------------------------------------------------------------------*/
void
 softfloat_shiftLeftM(
     uint_fast8_t size_words,
     const uint32_t *aPtr,
     uint32_t dist,
     uint32_t *zPtr
 );
#endif

#ifndef softfloat_shiftLeft96M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_shiftLeftM' with
| 'size_words' = 3 (N = 96).
*----------------------------------------------------------------------------*/
#define softfloat_shiftLeft96M( aPtr, dist, zPtr ) softfloat_shiftLeftM( 3, aPtr, dist, zPtr )
#endif

#ifndef softfloat_shiftLeft128M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_shiftLeftM' with
| 'size_words' = 4 (N = 128).
*----------------------------------------------------------------------------*/
#define softfloat_shiftLeft128M( aPtr, dist, zPtr ) softfloat_shiftLeftM( 4, aPtr, dist, zPtr )
#endif

#ifndef softfloat_shiftLeft160M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_shiftLeftM' with
| 'size_words' = 5 (N = 160).
*----------------------------------------------------------------------------*/
#define softfloat_shiftLeft160M( aPtr, dist, zPtr ) softfloat_shiftLeftM( 5, aPtr, dist, zPtr )
#endif

#ifndef softfloat_shortShiftRightM
/*----------------------------------------------------------------------------
| Shifts the N-bit unsigned integer pointed to by 'aPtr' right by the number
| of bits given in 'dist', where N = 'size_words' * 32.  The value of 'dist'
| must be in the range 1 to 31.  Any nonzero bits shifted off are lost.  The
| shifted N-bit result is stored at the location pointed to by 'zPtr'.  Each
| of 'aPtr' and 'zPtr' points to a 'size_words'-long array of 32-bit elements
| that concatenate in the platform's normal endian order to form an N-bit
| integer.
*----------------------------------------------------------------------------*/
void
 softfloat_shortShiftRightM(
     uint_fast8_t size_words,
     const uint32_t *aPtr,
     uint_fast8_t dist,
     uint32_t *zPtr
 );
#endif

#ifndef softfloat_shortShiftRight128M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_shortShiftRightM' with
| 'size_words' = 4 (N = 128).
*----------------------------------------------------------------------------*/
#define softfloat_shortShiftRight128M( aPtr, dist, zPtr ) softfloat_shortShiftRightM( 4, aPtr, dist, zPtr )
#endif

#ifndef softfloat_shortShiftRight160M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_shortShiftRightM' with
| 'size_words' = 5 (N = 160).
*----------------------------------------------------------------------------*/
#define softfloat_shortShiftRight160M( aPtr, dist, zPtr ) softfloat_shortShiftRightM( 5, aPtr, dist, zPtr )
#endif

#ifndef softfloat_shortShiftRightJamM
/*----------------------------------------------------------------------------
| Shifts the N-bit unsigned integer pointed to by 'aPtr' right by the number
| of bits given in 'dist', where N = 'size_words' * 32.  The value of 'dist'
| must be in the range 1 to 31.  If any nonzero bits are shifted off, they are
| "jammed" into the least-significant bit of the shifted value by setting the
| least-significant bit to 1.  This shifted-and-jammed N-bit result is stored
| at the location pointed to by 'zPtr'.  Each of 'aPtr' and 'zPtr' points
| to a 'size_words'-long array of 32-bit elements that concatenate in the
| platform's normal endian order to form an N-bit integer.
*----------------------------------------------------------------------------*/
void
 softfloat_shortShiftRightJamM(
     uint_fast8_t, const uint32_t *, uint_fast8_t, uint32_t * );
#endif

#ifndef softfloat_shortShiftRightJam160M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_shortShiftRightJamM' with
| 'size_words' = 5 (N = 160).
*----------------------------------------------------------------------------*/
#define softfloat_shortShiftRightJam160M( aPtr, dist, zPtr ) softfloat_shortShiftRightJamM( 5, aPtr, dist, zPtr )
#endif

#ifndef softfloat_shiftRightM
/*----------------------------------------------------------------------------
| Shifts the N-bit unsigned integer pointed to by 'aPtr' right by the number
| of bits given in 'dist', where N = 'size_words' * 32.  The value of 'dist'
| must not be zero.  Any nonzero bits shifted off are lost.  The shifted
| N-bit result is stored at the location pointed to by 'zPtr'.  Each of 'aPtr'
| and 'zPtr' points to a 'size_words'-long array of 32-bit elements that
| concatenate in the platform's normal endian order to form an N-bit integer.
|   The value of 'dist' can be arbitrarily large.  In particular, if 'dist' is
| greater than N, the stored result will be 0.
*----------------------------------------------------------------------------*/
void
 softfloat_shiftRightM(
     uint_fast8_t size_words,
     const uint32_t *aPtr,
     uint32_t dist,
     uint32_t *zPtr
 );
#endif

#ifndef softfloat_shiftRight96M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_shiftRightM' with
| 'size_words' = 3 (N = 96).
*----------------------------------------------------------------------------*/
#define softfloat_shiftRight96M( aPtr, dist, zPtr ) softfloat_shiftRightM( 3, aPtr, dist, zPtr )
#endif

#ifndef softfloat_shiftRightJamM
/*----------------------------------------------------------------------------
| Shifts the N-bit unsigned integer pointed to by 'aPtr' right by the number
| of bits given in 'dist', where N = 'size_words' * 32.  The value of 'dist'
| must not be zero.  If any nonzero bits are shifted off, they are "jammed"
| into the least-significant bit of the shifted value by setting the least-
| significant bit to 1.  This shifted-and-jammed N-bit result is stored
| at the location pointed to by 'zPtr'.  Each of 'aPtr' and 'zPtr' points
| to a 'size_words'-long array of 32-bit elements that concatenate in the
| platform's normal endian order to form an N-bit integer.
|   The value of 'dist' can be arbitrarily large.  In particular, if 'dist'
| is greater than N, the stored result will be either 0 or 1, depending on
| whether the original N bits are all zeros.
*----------------------------------------------------------------------------*/
void
 softfloat_shiftRightJamM(
     uint_fast8_t size_words,
     const uint32_t *aPtr,
     uint32_t dist,
     uint32_t *zPtr
 );
#endif

#ifndef softfloat_shiftRightJam96M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_shiftRightJamM' with
| 'size_words' = 3 (N = 96).
*----------------------------------------------------------------------------*/
#define softfloat_shiftRightJam96M( aPtr, dist, zPtr ) softfloat_shiftRightJamM( 3, aPtr, dist, zPtr )
#endif

#ifndef softfloat_shiftRightJam128M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_shiftRightJamM' with
| 'size_words' = 4 (N = 128).
*----------------------------------------------------------------------------*/
#define softfloat_shiftRightJam128M( aPtr, dist, zPtr ) softfloat_shiftRightJamM( 4, aPtr, dist, zPtr )
#endif

#ifndef softfloat_shiftRightJam160M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_shiftRightJamM' with
| 'size_words' = 5 (N = 160).
*----------------------------------------------------------------------------*/
#define softfloat_shiftRightJam160M( aPtr, dist, zPtr ) softfloat_shiftRightJamM( 5, aPtr, dist, zPtr )
#endif

#ifndef softfloat_addM
/*----------------------------------------------------------------------------
| Adds the two N-bit integers pointed to by 'aPtr' and 'bPtr', where N =
| 'size_words' * 32.  The addition is modulo 2^N, so any carry out is lost.
| The N-bit sum is stored at the location pointed to by 'zPtr'.  Each of
| 'aPtr', 'bPtr', and 'zPtr' points to a 'size_words'-long array of 32-bit
| elements that concatenate in the platform's normal endian order to form an
| N-bit integer.
*----------------------------------------------------------------------------*/
void
 softfloat_addM(
     uint_fast8_t size_words,
     const uint32_t *aPtr,
     const uint32_t *bPtr,
     uint32_t *zPtr
 );
#endif

#ifndef softfloat_add96M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_addM' with 'size_words'
| = 3 (N = 96).
*----------------------------------------------------------------------------*/
#define softfloat_add96M( aPtr, bPtr, zPtr ) softfloat_addM( 3, aPtr, bPtr, zPtr )
#endif

#ifndef softfloat_add128M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_addM' with 'size_words'
| = 4 (N = 128).
*----------------------------------------------------------------------------*/
#define softfloat_add128M( aPtr, bPtr, zPtr ) softfloat_addM( 4, aPtr, bPtr, zPtr )
#endif

#ifndef softfloat_add160M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_addM' with 'size_words'
| = 5 (N = 160).
*----------------------------------------------------------------------------*/
#define softfloat_add160M( aPtr, bPtr, zPtr ) softfloat_addM( 5, aPtr, bPtr, zPtr )
#endif

#ifndef softfloat_addCarryM
/*----------------------------------------------------------------------------
| Adds the two N-bit unsigned integers pointed to by 'aPtr' and 'bPtr', where
| N = 'size_words' * 32, plus 'carry', which must be either 0 or 1.  The N-bit
| sum (modulo 2^N) is stored at the location pointed to by 'zPtr', and any
| carry out is returned as the result.  Each of 'aPtr', 'bPtr', and 'zPtr'
| points to a 'size_words'-long array of 32-bit elements that concatenate in
| the platform's normal endian order to form an N-bit integer.
*----------------------------------------------------------------------------*/
uint_fast8_t
 softfloat_addCarryM(
     uint_fast8_t size_words,
     const uint32_t *aPtr,
     const uint32_t *bPtr,
     uint_fast8_t carry,
     uint32_t *zPtr
 );
#endif

#ifndef softfloat_addComplCarryM
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_addCarryM', except that
| the value of the unsigned integer pointed to by 'bPtr' is bit-wise completed
| before the addition.
*----------------------------------------------------------------------------*/
uint_fast8_t
 softfloat_addComplCarryM(
     uint_fast8_t size_words,
     const uint32_t *aPtr,
     const uint32_t *bPtr,
     uint_fast8_t carry,
     uint32_t *zPtr
 );
#endif

#ifndef softfloat_addComplCarry96M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_addComplCarryM' with
| 'size_words' = 3 (N = 96).
*----------------------------------------------------------------------------*/
#define softfloat_addComplCarry96M( aPtr, bPtr, carry, zPtr ) softfloat_addComplCarryM( 3, aPtr, bPtr, carry, zPtr )
#endif

#ifndef softfloat_negXM
/*----------------------------------------------------------------------------
| Replaces the N-bit unsigned integer pointed to by 'zPtr' by the
| 2s-complement of itself, where N = 'size_words' * 32.  Argument 'zPtr'
| points to a 'size_words'-long array of 32-bit elements that concatenate in
| the platform's normal endian order to form an N-bit integer.
*----------------------------------------------------------------------------*/
void softfloat_negXM( uint_fast8_t size_words, uint32_t *zPtr );
#endif

#ifndef softfloat_negX96M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_negXM' with 'size_words'
| = 3 (N = 96).
*----------------------------------------------------------------------------*/
#define softfloat_negX96M( zPtr ) softfloat_negXM( 3, zPtr )
#endif

#ifndef softfloat_negX128M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_negXM' with 'size_words'
| = 4 (N = 128).
*----------------------------------------------------------------------------*/
#define softfloat_negX128M( zPtr ) softfloat_negXM( 4, zPtr )
#endif

#ifndef softfloat_negX160M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_negXM' with 'size_words'
| = 5 (N = 160).
*----------------------------------------------------------------------------*/
#define softfloat_negX160M( zPtr ) softfloat_negXM( 5, zPtr )
#endif

#ifndef softfloat_negX256M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_negXM' with 'size_words'
| = 8 (N = 256).
*----------------------------------------------------------------------------*/
#define softfloat_negX256M( zPtr ) softfloat_negXM( 8, zPtr )
#endif

#ifndef softfloat_sub1XM
/*----------------------------------------------------------------------------
| Subtracts 1 from the N-bit integer pointed to by 'zPtr', where N =
| 'size_words' * 32.  The subtraction is modulo 2^N, so any borrow out (carry
| out) is lost.  Argument 'zPtr' points to a 'size_words'-long array of 32-bit
| elements that concatenate in the platform's normal endian order to form an
| N-bit integer.
*----------------------------------------------------------------------------*/
void softfloat_sub1XM( uint_fast8_t size_words, uint32_t *zPtr );
#endif

#ifndef softfloat_sub1X96M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_sub1XM' with 'size_words'
| = 3 (N = 96).
*----------------------------------------------------------------------------*/
#define softfloat_sub1X96M( zPtr ) softfloat_sub1XM( 3, zPtr )
#endif

#ifndef softfloat_sub1X160M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_sub1XM' with 'size_words'
| = 5 (N = 160).
*----------------------------------------------------------------------------*/
#define softfloat_sub1X160M( zPtr ) softfloat_sub1XM( 5, zPtr )
#endif

#ifndef softfloat_subM
/*----------------------------------------------------------------------------
| Subtracts the two N-bit integers pointed to by 'aPtr' and 'bPtr', where N =
| 'size_words' * 32.  The subtraction is modulo 2^N, so any borrow out (carry
| out) is lost.  The N-bit difference is stored at the location pointed to by
| 'zPtr'.  Each of 'aPtr', 'bPtr', and 'zPtr' points to a 'size_words'-long
| array of 32-bit elements that concatenate in the platform's normal endian
| order to form an N-bit integer.
*----------------------------------------------------------------------------*/
void
 softfloat_subM(
     uint_fast8_t size_words,
     const uint32_t *aPtr,
     const uint32_t *bPtr,
     uint32_t *zPtr
 );
#endif

#ifndef softfloat_sub96M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_subM' with 'size_words'
| = 3 (N = 96).
*----------------------------------------------------------------------------*/
#define softfloat_sub96M( aPtr, bPtr, zPtr ) softfloat_subM( 3, aPtr, bPtr, zPtr )
#endif

#ifndef softfloat_sub128M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_subM' with 'size_words'
| = 4 (N = 128).
*----------------------------------------------------------------------------*/
#define softfloat_sub128M( aPtr, bPtr, zPtr ) softfloat_subM( 4, aPtr, bPtr, zPtr )
#endif

#ifndef softfloat_sub160M
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_subM' with 'size_words'
| = 5 (N = 160).
*----------------------------------------------------------------------------*/
#define softfloat_sub160M( aPtr, bPtr, zPtr ) softfloat_subM( 5, aPtr, bPtr, zPtr )
#endif

#ifndef softfloat_mul64To128M
/*----------------------------------------------------------------------------
| Multiplies 'a' and 'b' and stores the 128-bit product at the location
| pointed to by 'zPtr'.  Argument 'zPtr' points to an array of four 32-bit
| elements that concatenate in the platform's normal endian order to form a
| 128-bit integer.
*----------------------------------------------------------------------------*/
void softfloat_mul64To128M( uint64_t a, uint64_t b, uint32_t *zPtr );
#endif

#ifndef softfloat_mul128MTo256M
/*----------------------------------------------------------------------------
| Multiplies the two 128-bit unsigned integers pointed to by 'aPtr' and
| 'bPtr', and stores the 256-bit product at the location pointed to by 'zPtr'.
| Each of 'aPtr' and 'bPtr' points to an array of four 32-bit elements that
| concatenate in the platform's normal endian order to form a 128-bit integer.
| Argument 'zPtr' points to an array of eight 32-bit elements that concatenate
| to form a 256-bit integer.
*----------------------------------------------------------------------------*/
void
 softfloat_mul128MTo256M(
     const uint32_t *aPtr, const uint32_t *bPtr, uint32_t *zPtr );
#endif

#ifndef softfloat_remStepMBy32
/*----------------------------------------------------------------------------
| Performs a "remainder reduction step" as follows:  Arguments 'remPtr' and
| 'bPtr' both point to N-bit unsigned integers, where N = 'size_words' * 32.
| Defining R and B as the values of those integers, the expression (R<<'dist')
| - B * q is computed modulo 2^N, and the N-bit result is stored at the
| location pointed to by 'zPtr'.  Each of 'remPtr', 'bPtr', and 'zPtr' points
| to a 'size_words'-long array of 32-bit elements that concatenate in the
| platform's normal endian order to form an N-bit integer.
*----------------------------------------------------------------------------*/
void
 softfloat_remStepMBy32(
     uint_fast8_t size_words,
     const uint32_t *remPtr,
     uint_fast8_t dist,
     const uint32_t *bPtr,
     uint32_t q,
     uint32_t *zPtr
 );
#endif

#ifndef softfloat_remStep96MBy32
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_remStepMBy32' with
| 'size_words' = 3 (N = 96).
*----------------------------------------------------------------------------*/
#define softfloat_remStep96MBy32( remPtr, dist, bPtr, q, zPtr ) softfloat_remStepMBy32( 3, remPtr, dist, bPtr, q, zPtr )
#endif

#ifndef softfloat_remStep128MBy32
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_remStepMBy32' with
| 'size_words' = 4 (N = 128).
*----------------------------------------------------------------------------*/
#define softfloat_remStep128MBy32( remPtr, dist, bPtr, q, zPtr ) softfloat_remStepMBy32( 4, remPtr, dist, bPtr, q, zPtr )
#endif

#ifndef softfloat_remStep160MBy32
/*----------------------------------------------------------------------------
| This function or macro is the same as 'softfloat_remStepMBy32' with
| 'size_words' = 5 (N = 160).
*----------------------------------------------------------------------------*/
#define softfloat_remStep160MBy32( remPtr, dist, bPtr, q, zPtr ) softfloat_remStepMBy32( 5, remPtr, dist, bPtr, q, zPtr )
#endif

#endif

#endif

