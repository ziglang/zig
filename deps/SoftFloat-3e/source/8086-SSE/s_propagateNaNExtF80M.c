
/*============================================================================

This C source file is part of the SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3e, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014 The Regents of the University of California.
All rights reserved.

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
| Assuming at least one of the two 80-bit extended floating-point values
| pointed to by `aSPtr' and `bSPtr' is a NaN, stores the combined NaN result
| at the location pointed to by `zSPtr'.  If either original floating-point
| value is a signaling NaN, the invalid exception is raised.
*----------------------------------------------------------------------------*/
void
 softfloat_propagateNaNExtF80M(
     const struct extFloat80M *aSPtr,
     const struct extFloat80M *bSPtr,
     struct extFloat80M *zSPtr
 )
{
    bool isSigNaNA;
    const struct extFloat80M *sPtr;
    bool isSigNaNB;
    uint_fast16_t uiB64;
    uint64_t uiB0;
    uint_fast16_t uiA64;
    uint64_t uiA0;
    uint_fast16_t uiMagA64, uiMagB64;

    isSigNaNA = extF80M_isSignalingNaN( (const extFloat80_t *) aSPtr );
    sPtr = aSPtr;
    if ( ! bSPtr ) {
        if ( isSigNaNA ) softfloat_raiseFlags( softfloat_flag_invalid );
        goto copy;
    }
    isSigNaNB = extF80M_isSignalingNaN( (const extFloat80_t *) bSPtr );
    if ( isSigNaNA | isSigNaNB ) {
        softfloat_raiseFlags( softfloat_flag_invalid );
        if ( isSigNaNA ) {
            uiB64 = bSPtr->signExp;
            if ( isSigNaNB ) goto returnLargerUIMag;
            uiB0 = bSPtr->signif;
            if ( isNaNExtF80UI( uiB64, uiB0 ) ) goto copyB;
            goto copy;
        } else {
            uiA64 = aSPtr->signExp;
            uiA0 = aSPtr->signif;
            if ( isNaNExtF80UI( uiA64, uiA0 ) ) goto copy;
            goto copyB;
        }
    }
    uiB64 = bSPtr->signExp;
 returnLargerUIMag:
    uiA64 = aSPtr->signExp;
    uiMagA64 = uiA64 & 0x7FFF;
    uiMagB64 = uiB64 & 0x7FFF;
    if ( uiMagA64 < uiMagB64 ) goto copyB;
    if ( uiMagB64 < uiMagA64 ) goto copy;
    uiA0 = aSPtr->signif;
    uiB0 = bSPtr->signif;
    if ( uiA0 < uiB0 ) goto copyB;
    if ( uiB0 < uiA0 ) goto copy;
    if ( uiA64 < uiB64 ) goto copy;
 copyB:
    sPtr = bSPtr;
 copy:
    zSPtr->signExp = sPtr->signExp;
    zSPtr->signif = sPtr->signif | UINT64_C( 0xC000000000000000 );

}

