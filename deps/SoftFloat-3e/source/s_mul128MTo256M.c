
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
#include "primitiveTypes.h"

#ifndef softfloat_mul128MTo256M

void
 softfloat_mul128MTo256M(
     const uint32_t *aPtr, const uint32_t *bPtr, uint32_t *zPtr )
{
    uint32_t *lastZPtr, wordB;
    uint64_t dwordProd;
    uint32_t wordZ;
    uint_fast8_t carry;

    bPtr += indexWordLo( 4 );
    lastZPtr = zPtr + indexMultiwordHi( 8, 5 );
    zPtr += indexMultiwordLo( 8, 5 );
    wordB = *bPtr;
    dwordProd = (uint64_t) aPtr[indexWord( 4, 0 )] * wordB;
    zPtr[indexWord( 5, 0 )] = dwordProd;
    dwordProd = (uint64_t) aPtr[indexWord( 4, 1 )] * wordB + (dwordProd>>32);
    zPtr[indexWord( 5, 1 )] = dwordProd;
    dwordProd = (uint64_t) aPtr[indexWord( 4, 2 )] * wordB + (dwordProd>>32);
    zPtr[indexWord( 5, 2 )] = dwordProd;
    dwordProd = (uint64_t) aPtr[indexWord( 4, 3 )] * wordB + (dwordProd>>32);
    zPtr[indexWord( 5, 3 )] = dwordProd;
    zPtr[indexWord( 5, 4 )] = dwordProd>>32;
    do {
        bPtr += wordIncr;
        zPtr += wordIncr;
        wordB = *bPtr;
        dwordProd = (uint64_t) aPtr[indexWord( 4, 0 )] * wordB;
        wordZ = zPtr[indexWord( 5, 0 )] + (uint32_t) dwordProd;
        zPtr[indexWord( 5, 0 )] = wordZ;
        carry = (wordZ < (uint32_t) dwordProd);
        dwordProd =
            (uint64_t) aPtr[indexWord( 4, 1 )] * wordB + (dwordProd>>32);
        wordZ = zPtr[indexWord( 5, 1 )] + (uint32_t) dwordProd + carry;
        zPtr[indexWord( 5, 1 )] = wordZ;
        if ( wordZ != (uint32_t) dwordProd ) {
            carry = (wordZ < (uint32_t) dwordProd);
        }
        dwordProd =
            (uint64_t) aPtr[indexWord( 4, 2 )] * wordB + (dwordProd>>32);
        wordZ = zPtr[indexWord( 5, 2 )] + (uint32_t) dwordProd + carry;
        zPtr[indexWord( 5, 2 )] = wordZ;
        if ( wordZ != (uint32_t) dwordProd ) {
            carry = (wordZ < (uint32_t) dwordProd);
        }
        dwordProd =
            (uint64_t) aPtr[indexWord( 4, 3 )] * wordB + (dwordProd>>32);
        wordZ = zPtr[indexWord( 5, 3 )] + (uint32_t) dwordProd + carry;
        zPtr[indexWord( 5, 3 )] = wordZ;
        if ( wordZ != (uint32_t) dwordProd ) {
            carry = (wordZ < (uint32_t) dwordProd);
        }
        zPtr[indexWord( 5, 4 )] = (dwordProd>>32) + carry;
    } while ( zPtr != lastZPtr );

}

#endif

