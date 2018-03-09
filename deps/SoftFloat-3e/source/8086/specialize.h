
/*============================================================================

This C header file is part of the SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3e, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014, 2015, 2016, 2018 The Regents of the
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

#ifndef specialize_h
#define specialize_h 1

#include <stdbool.h>
#include <stdint.h>
#include "primitiveTypes.h"
#include "softfloat.h"

/*----------------------------------------------------------------------------
| Default value for 'softfloat_detectTininess'.
*----------------------------------------------------------------------------*/
#define init_detectTininess softfloat_tininess_afterRounding

/*----------------------------------------------------------------------------
| The values to return on conversions to 32-bit integer formats that raise an
| invalid exception.
*----------------------------------------------------------------------------*/
#define ui32_fromPosOverflow 0xFFFFFFFF
#define ui32_fromNegOverflow 0xFFFFFFFF
#define ui32_fromNaN         0xFFFFFFFF
#define i32_fromPosOverflow  (-0x7FFFFFFF - 1)
#define i32_fromNegOverflow  (-0x7FFFFFFF - 1)
#define i32_fromNaN          (-0x7FFFFFFF - 1)

/*----------------------------------------------------------------------------
| The values to return on conversions to 64-bit integer formats that raise an
| invalid exception.
*----------------------------------------------------------------------------*/
#define ui64_fromPosOverflow UINT64_C( 0xFFFFFFFFFFFFFFFF )
#define ui64_fromNegOverflow UINT64_C( 0xFFFFFFFFFFFFFFFF )
#define ui64_fromNaN         UINT64_C( 0xFFFFFFFFFFFFFFFF )
#define i64_fromPosOverflow  (-INT64_C( 0x7FFFFFFFFFFFFFFF ) - 1)
#define i64_fromNegOverflow  (-INT64_C( 0x7FFFFFFFFFFFFFFF ) - 1)
#define i64_fromNaN          (-INT64_C( 0x7FFFFFFFFFFFFFFF ) - 1)

/*----------------------------------------------------------------------------
| "Common NaN" structure, used to transfer NaN representations from one format
| to another.
*----------------------------------------------------------------------------*/
struct commonNaN {
    bool sign;
#ifdef LITTLEENDIAN
    uint64_t v0, v64;
#else
    uint64_t v64, v0;
#endif
};

/*----------------------------------------------------------------------------
| The bit pattern for a default generated 16-bit floating-point NaN.
*----------------------------------------------------------------------------*/
#define defaultNaNF16UI 0xFE00

/*----------------------------------------------------------------------------
| Returns true when 16-bit unsigned integer 'uiA' has the bit pattern of a
| 16-bit floating-point signaling NaN.
| Note:  This macro evaluates its argument more than once.
*----------------------------------------------------------------------------*/
#define softfloat_isSigNaNF16UI( uiA ) ((((uiA) & 0x7E00) == 0x7C00) && ((uiA) & 0x01FF))

/*----------------------------------------------------------------------------
| Assuming 'uiA' has the bit pattern of a 16-bit floating-point NaN, converts
| this NaN to the common NaN form, and stores the resulting common NaN at the
| location pointed to by 'zPtr'.  If the NaN is a signaling NaN, the invalid
| exception is raised.
*----------------------------------------------------------------------------*/
void softfloat_f16UIToCommonNaN( uint_fast16_t uiA, struct commonNaN *zPtr );

/*----------------------------------------------------------------------------
| Converts the common NaN pointed to by 'aPtr' into a 16-bit floating-point
| NaN, and returns the bit pattern of this value as an unsigned integer.
*----------------------------------------------------------------------------*/
uint_fast16_t softfloat_commonNaNToF16UI( const struct commonNaN *aPtr );

/*----------------------------------------------------------------------------
| Interpreting 'uiA' and 'uiB' as the bit patterns of two 16-bit floating-
| point values, at least one of which is a NaN, returns the bit pattern of
| the combined NaN result.  If either 'uiA' or 'uiB' has the pattern of a
| signaling NaN, the invalid exception is raised.
*----------------------------------------------------------------------------*/
uint_fast16_t
 softfloat_propagateNaNF16UI( uint_fast16_t uiA, uint_fast16_t uiB );

/*----------------------------------------------------------------------------
| The bit pattern for a default generated 32-bit floating-point NaN.
*----------------------------------------------------------------------------*/
#define defaultNaNF32UI 0xFFC00000

/*----------------------------------------------------------------------------
| Returns true when 32-bit unsigned integer 'uiA' has the bit pattern of a
| 32-bit floating-point signaling NaN.
| Note:  This macro evaluates its argument more than once.
*----------------------------------------------------------------------------*/
#define softfloat_isSigNaNF32UI( uiA ) ((((uiA) & 0x7FC00000) == 0x7F800000) && ((uiA) & 0x003FFFFF))

/*----------------------------------------------------------------------------
| Assuming 'uiA' has the bit pattern of a 32-bit floating-point NaN, converts
| this NaN to the common NaN form, and stores the resulting common NaN at the
| location pointed to by 'zPtr'.  If the NaN is a signaling NaN, the invalid
| exception is raised.
*----------------------------------------------------------------------------*/
void softfloat_f32UIToCommonNaN( uint_fast32_t uiA, struct commonNaN *zPtr );

/*----------------------------------------------------------------------------
| Converts the common NaN pointed to by 'aPtr' into a 32-bit floating-point
| NaN, and returns the bit pattern of this value as an unsigned integer.
*----------------------------------------------------------------------------*/
uint_fast32_t softfloat_commonNaNToF32UI( const struct commonNaN *aPtr );

/*----------------------------------------------------------------------------
| Interpreting 'uiA' and 'uiB' as the bit patterns of two 32-bit floating-
| point values, at least one of which is a NaN, returns the bit pattern of
| the combined NaN result.  If either 'uiA' or 'uiB' has the pattern of a
| signaling NaN, the invalid exception is raised.
*----------------------------------------------------------------------------*/
uint_fast32_t
 softfloat_propagateNaNF32UI( uint_fast32_t uiA, uint_fast32_t uiB );

/*----------------------------------------------------------------------------
| The bit pattern for a default generated 64-bit floating-point NaN.
*----------------------------------------------------------------------------*/
#define defaultNaNF64UI UINT64_C( 0xFFF8000000000000 )

/*----------------------------------------------------------------------------
| Returns true when 64-bit unsigned integer 'uiA' has the bit pattern of a
| 64-bit floating-point signaling NaN.
| Note:  This macro evaluates its argument more than once.
*----------------------------------------------------------------------------*/
#define softfloat_isSigNaNF64UI( uiA ) ((((uiA) & UINT64_C( 0x7FF8000000000000 )) == UINT64_C( 0x7FF0000000000000 )) && ((uiA) & UINT64_C( 0x0007FFFFFFFFFFFF )))

/*----------------------------------------------------------------------------
| Assuming 'uiA' has the bit pattern of a 64-bit floating-point NaN, converts
| this NaN to the common NaN form, and stores the resulting common NaN at the
| location pointed to by 'zPtr'.  If the NaN is a signaling NaN, the invalid
| exception is raised.
*----------------------------------------------------------------------------*/
void softfloat_f64UIToCommonNaN( uint_fast64_t uiA, struct commonNaN *zPtr );

/*----------------------------------------------------------------------------
| Converts the common NaN pointed to by 'aPtr' into a 64-bit floating-point
| NaN, and returns the bit pattern of this value as an unsigned integer.
*----------------------------------------------------------------------------*/
uint_fast64_t softfloat_commonNaNToF64UI( const struct commonNaN *aPtr );

/*----------------------------------------------------------------------------
| Interpreting 'uiA' and 'uiB' as the bit patterns of two 64-bit floating-
| point values, at least one of which is a NaN, returns the bit pattern of
| the combined NaN result.  If either 'uiA' or 'uiB' has the pattern of a
| signaling NaN, the invalid exception is raised.
*----------------------------------------------------------------------------*/
uint_fast64_t
 softfloat_propagateNaNF64UI( uint_fast64_t uiA, uint_fast64_t uiB );

/*----------------------------------------------------------------------------
| The bit pattern for a default generated 80-bit extended floating-point NaN.
*----------------------------------------------------------------------------*/
#define defaultNaNExtF80UI64 0xFFFF
#define defaultNaNExtF80UI0  UINT64_C( 0xC000000000000000 )

/*----------------------------------------------------------------------------
| Returns true when the 80-bit unsigned integer formed from concatenating
| 16-bit 'uiA64' and 64-bit 'uiA0' has the bit pattern of an 80-bit extended
| floating-point signaling NaN.
| Note:  This macro evaluates its arguments more than once.
*----------------------------------------------------------------------------*/
#define softfloat_isSigNaNExtF80UI( uiA64, uiA0 ) ((((uiA64) & 0x7FFF) == 0x7FFF) && ! ((uiA0) & UINT64_C( 0x4000000000000000 )) && ((uiA0) & UINT64_C( 0x3FFFFFFFFFFFFFFF )))

#ifdef SOFTFLOAT_FAST_INT64

/*----------------------------------------------------------------------------
| The following functions are needed only when 'SOFTFLOAT_FAST_INT64' is
| defined.
*----------------------------------------------------------------------------*/

/*----------------------------------------------------------------------------
| Assuming the unsigned integer formed from concatenating 'uiA64' and 'uiA0'
| has the bit pattern of an 80-bit extended floating-point NaN, converts
| this NaN to the common NaN form, and stores the resulting common NaN at the
| location pointed to by 'zPtr'.  If the NaN is a signaling NaN, the invalid
| exception is raised.
*----------------------------------------------------------------------------*/
void
 softfloat_extF80UIToCommonNaN(
     uint_fast16_t uiA64, uint_fast64_t uiA0, struct commonNaN *zPtr );

/*----------------------------------------------------------------------------
| Converts the common NaN pointed to by 'aPtr' into an 80-bit extended
| floating-point NaN, and returns the bit pattern of this value as an unsigned
| integer.
*----------------------------------------------------------------------------*/
struct uint128 softfloat_commonNaNToExtF80UI( const struct commonNaN *aPtr );

/*----------------------------------------------------------------------------
| Interpreting the unsigned integer formed from concatenating 'uiA64' and
| 'uiA0' as an 80-bit extended floating-point value, and likewise interpreting
| the unsigned integer formed from concatenating 'uiB64' and 'uiB0' as another
| 80-bit extended floating-point value, and assuming at least on of these
| floating-point values is a NaN, returns the bit pattern of the combined NaN
| result.  If either original floating-point value is a signaling NaN, the
| invalid exception is raised.
*----------------------------------------------------------------------------*/
struct uint128
 softfloat_propagateNaNExtF80UI(
     uint_fast16_t uiA64,
     uint_fast64_t uiA0,
     uint_fast16_t uiB64,
     uint_fast64_t uiB0
 );

/*----------------------------------------------------------------------------
| The bit pattern for a default generated 128-bit floating-point NaN.
*----------------------------------------------------------------------------*/
#define defaultNaNF128UI64 UINT64_C( 0xFFFF800000000000 )
#define defaultNaNF128UI0  UINT64_C( 0 )

/*----------------------------------------------------------------------------
| Returns true when the 128-bit unsigned integer formed from concatenating
| 64-bit 'uiA64' and 64-bit 'uiA0' has the bit pattern of a 128-bit floating-
| point signaling NaN.
| Note:  This macro evaluates its arguments more than once.
*----------------------------------------------------------------------------*/
#define softfloat_isSigNaNF128UI( uiA64, uiA0 ) ((((uiA64) & UINT64_C( 0x7FFF800000000000 )) == UINT64_C( 0x7FFF000000000000 )) && ((uiA0) || ((uiA64) & UINT64_C( 0x00007FFFFFFFFFFF ))))

/*----------------------------------------------------------------------------
| Assuming the unsigned integer formed from concatenating 'uiA64' and 'uiA0'
| has the bit pattern of a 128-bit floating-point NaN, converts this NaN to
| the common NaN form, and stores the resulting common NaN at the location
| pointed to by 'zPtr'.  If the NaN is a signaling NaN, the invalid exception
| is raised.
*----------------------------------------------------------------------------*/
void
 softfloat_f128UIToCommonNaN(
     uint_fast64_t uiA64, uint_fast64_t uiA0, struct commonNaN *zPtr );

/*----------------------------------------------------------------------------
| Converts the common NaN pointed to by 'aPtr' into a 128-bit floating-point
| NaN, and returns the bit pattern of this value as an unsigned integer.
*----------------------------------------------------------------------------*/
struct uint128 softfloat_commonNaNToF128UI( const struct commonNaN * );

/*----------------------------------------------------------------------------
| Interpreting the unsigned integer formed from concatenating 'uiA64' and
| 'uiA0' as a 128-bit floating-point value, and likewise interpreting the
| unsigned integer formed from concatenating 'uiB64' and 'uiB0' as another
| 128-bit floating-point value, and assuming at least on of these floating-
| point values is a NaN, returns the bit pattern of the combined NaN result.
| If either original floating-point value is a signaling NaN, the invalid
| exception is raised.
*----------------------------------------------------------------------------*/
struct uint128
 softfloat_propagateNaNF128UI(
     uint_fast64_t uiA64,
     uint_fast64_t uiA0,
     uint_fast64_t uiB64,
     uint_fast64_t uiB0
 );

#else

/*----------------------------------------------------------------------------
| The following functions are needed only when 'SOFTFLOAT_FAST_INT64' is not
| defined.
*----------------------------------------------------------------------------*/

/*----------------------------------------------------------------------------
| Assuming the 80-bit extended floating-point value pointed to by 'aSPtr' is
| a NaN, converts this NaN to the common NaN form, and stores the resulting
| common NaN at the location pointed to by 'zPtr'.  If the NaN is a signaling
| NaN, the invalid exception is raised.
*----------------------------------------------------------------------------*/
void
 softfloat_extF80MToCommonNaN(
     const struct extFloat80M *aSPtr, struct commonNaN *zPtr );

/*----------------------------------------------------------------------------
| Converts the common NaN pointed to by 'aPtr' into an 80-bit extended
| floating-point NaN, and stores this NaN at the location pointed to by
| 'zSPtr'.
*----------------------------------------------------------------------------*/
void
 softfloat_commonNaNToExtF80M(
     const struct commonNaN *aPtr, struct extFloat80M *zSPtr );

/*----------------------------------------------------------------------------
| Assuming at least one of the two 80-bit extended floating-point values
| pointed to by 'aSPtr' and 'bSPtr' is a NaN, stores the combined NaN result
| at the location pointed to by 'zSPtr'.  If either original floating-point
| value is a signaling NaN, the invalid exception is raised.
*----------------------------------------------------------------------------*/
void
 softfloat_propagateNaNExtF80M(
     const struct extFloat80M *aSPtr,
     const struct extFloat80M *bSPtr,
     struct extFloat80M *zSPtr
 );

/*----------------------------------------------------------------------------
| The bit pattern for a default generated 128-bit floating-point NaN.
*----------------------------------------------------------------------------*/
#define defaultNaNF128UI96 0xFFFF8000
#define defaultNaNF128UI64 0
#define defaultNaNF128UI32 0
#define defaultNaNF128UI0  0

/*----------------------------------------------------------------------------
| Assuming the 128-bit floating-point value pointed to by 'aWPtr' is a NaN,
| converts this NaN to the common NaN form, and stores the resulting common
| NaN at the location pointed to by 'zPtr'.  If the NaN is a signaling NaN,
| the invalid exception is raised.  Argument 'aWPtr' points to an array of
| four 32-bit elements that concatenate in the platform's normal endian order
| to form a 128-bit floating-point value.
*----------------------------------------------------------------------------*/
void
 softfloat_f128MToCommonNaN( const uint32_t *aWPtr, struct commonNaN *zPtr );

/*----------------------------------------------------------------------------
| Converts the common NaN pointed to by 'aPtr' into a 128-bit floating-point
| NaN, and stores this NaN at the location pointed to by 'zWPtr'.  Argument
| 'zWPtr' points to an array of four 32-bit elements that concatenate in the
| platform's normal endian order to form a 128-bit floating-point value.
*----------------------------------------------------------------------------*/
void
 softfloat_commonNaNToF128M( const struct commonNaN *aPtr, uint32_t *zWPtr );

/*----------------------------------------------------------------------------
| Assuming at least one of the two 128-bit floating-point values pointed to by
| 'aWPtr' and 'bWPtr' is a NaN, stores the combined NaN result at the location
| pointed to by 'zWPtr'.  If either original floating-point value is a
| signaling NaN, the invalid exception is raised.  Each of 'aWPtr', 'bWPtr',
| and 'zWPtr' points to an array of four 32-bit elements that concatenate in
| the platform's normal endian order to form a 128-bit floating-point value.
*----------------------------------------------------------------------------*/
void
 softfloat_propagateNaNF128M(
     const uint32_t *aWPtr, const uint32_t *bWPtr, uint32_t *zWPtr );

#endif

#endif

