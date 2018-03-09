
/*============================================================================

This C source file is part of the SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3e, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014, 2018 The Regents of the University of
California.  All rights reserved.

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

#include <stdbool.h>
#include <stdint.h>
#include "platform.h"
#include "internals.h"
#include "specialize.h"
#include "softfloat.h"

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
 )
{
    bool isSigNaNA, isSigNaNB;
    uint_fast64_t uiNonsigA64, uiNonsigB64, uiMagA64, uiMagB64;
    struct uint128 uiZ;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    isSigNaNA = softfloat_isSigNaNF128UI( uiA64, uiA0 );
    isSigNaNB = softfloat_isSigNaNF128UI( uiB64, uiB0 );
    /*------------------------------------------------------------------------
    | Make NaNs non-signaling.
    *------------------------------------------------------------------------*/
    uiNonsigA64 = uiA64 | UINT64_C( 0x0000800000000000 );
    uiNonsigB64 = uiB64 | UINT64_C( 0x0000800000000000 );
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( isSigNaNA | isSigNaNB ) {
        softfloat_raiseFlags( softfloat_flag_invalid );
        if ( isSigNaNA ) {
            if ( isSigNaNB ) goto returnLargerMag;
            if ( isNaNF128UI( uiB64, uiB0 ) ) goto returnB;
            goto returnA;
        } else {
            if ( isNaNF128UI( uiA64, uiA0 ) ) goto returnA;
            goto returnB;
        }
    }
 returnLargerMag:
    uiMagA64 = uiA64 & UINT64_C( 0x7FFFFFFFFFFFFFFF );
    uiMagB64 = uiB64 & UINT64_C( 0x7FFFFFFFFFFFFFFF );
    if ( uiMagA64 < uiMagB64 ) goto returnB;
    if ( uiMagB64 < uiMagA64 ) goto returnA;
    if ( uiA0 < uiB0 ) goto returnB;
    if ( uiB0 < uiA0 ) goto returnA;
    if ( uiNonsigA64 < uiNonsigB64 ) goto returnA;
 returnB:
    uiZ.v64 = uiNonsigB64;
    uiZ.v0  = uiB0;
    return uiZ;
 returnA:
    uiZ.v64 = uiNonsigA64;
    uiZ.v0  = uiA0;
    return uiZ;

}

