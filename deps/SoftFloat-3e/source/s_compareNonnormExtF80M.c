
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

#include <stdint.h>
#include "platform.h"
#include "internals.h"
#include "softfloat_types.h"

int
 softfloat_compareNonnormExtF80M(
     const struct extFloat80M *aSPtr, const struct extFloat80M *bSPtr )
{
    uint_fast16_t uiA64, uiB64;
    uint64_t sigA;
    bool signB;
    uint64_t sigB;
    int32_t expA, expB;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    uiA64 = aSPtr->signExp;
    uiB64 = bSPtr->signExp;
    sigA = aSPtr->signif;
    signB = signExtF80UI64( uiB64 );
    sigB = bSPtr->signif;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( (uiA64 ^ uiB64) & 0x8000 ) {
        if ( ! (sigA | sigB) ) return 0;
        goto resultFromSignB;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    expA = expExtF80UI64( uiA64 );
    expB = expExtF80UI64( uiB64 );
    if ( expA == 0x7FFF ) {
        if (expB == 0x7FFF) return 0;
        signB = ! signB;
        goto resultFromSignB;
    }
    if ( expB == 0x7FFF ) {
        goto resultFromSignB;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( ! expA ) expA = 1;
    if ( ! (sigA & UINT64_C( 0x8000000000000000 )) ) {
        if ( sigA ) {
            expA += softfloat_normExtF80SigM( &sigA );
        } else {
            expA = -128;
        }
    }
    if ( ! expB ) expB = 1;
    if ( ! (sigB & UINT64_C( 0x8000000000000000 )) ) {
        if ( sigB ) {
            expB += softfloat_normExtF80SigM( &sigB );
        } else {
            expB = -128;
        }
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    if ( signB ) {
        if ( expA < expB ) return 1;
        if ( (expB < expA) || (sigB < sigA) ) return -1;
    } else {
        if ( expB < expA ) return 1;
        if ( (expA < expB) || (sigA < sigB) ) return -1;
    }
    return (sigA != sigB);
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 resultFromSignB:
    return signB ? 1 : -1;

}

