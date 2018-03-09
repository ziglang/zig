
/*============================================================================

This C source file is part of the SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3e, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014, 2015, 2016 The Regents of the University of
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

#include <stdint.h>
#include "platform.h"
#include "internals.h"

int
 softfloat_shiftNormSigF128M(
     const uint32_t *wPtr, uint_fast8_t shiftDist, uint32_t *sigPtr )
{
    uint32_t wordSig;
    int32_t exp;
    uint32_t leadingBit;

    wordSig = wPtr[indexWordHi( 4 )];
    exp = expF128UI96( wordSig );
    if ( exp ) {
        softfloat_shortShiftLeft128M( wPtr, shiftDist, sigPtr );
        leadingBit = 0x00010000<<shiftDist;
        sigPtr[indexWordHi( 4 )] =
            (sigPtr[indexWordHi( 4 )] & (leadingBit - 1)) | leadingBit;
    } else {
        exp = 16;
        wordSig &= 0x7FFFFFFF;
        if ( ! wordSig ) {
            exp = -16;
            wordSig = wPtr[indexWord( 4, 2 )];
            if ( ! wordSig ) {
                exp = -48;
                wordSig = wPtr[indexWord( 4, 1 )];
                if ( ! wordSig ) {
                    wordSig = wPtr[indexWord( 4, 0 )];
                    if ( ! wordSig ) return -128;
                    exp = -80;
                }
            }
        }
        exp -= softfloat_countLeadingZeros32( wordSig );
        softfloat_shiftLeft128M( wPtr, 1 - exp + shiftDist, sigPtr );
    }
    return exp;

}

