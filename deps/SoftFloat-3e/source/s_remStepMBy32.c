
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

#ifndef softfloat_remStepMBy32

void
 softfloat_remStepMBy32(
     uint_fast8_t size_words,
     const uint32_t *remPtr,
     uint_fast8_t dist,
     const uint32_t *bPtr,
     uint32_t q,
     uint32_t *zPtr
 )
{
    unsigned int index, lastIndex;
    uint64_t dwordProd;
    uint32_t wordRem, wordShiftedRem, wordProd;
    uint_fast8_t uNegDist, borrow;

    index = indexWordLo( size_words );
    lastIndex = indexWordHi( size_words );
    dwordProd = (uint64_t) bPtr[index] * q;
    wordRem = remPtr[index];
    wordShiftedRem = wordRem<<dist;
    wordProd = dwordProd;
    zPtr[index] = wordShiftedRem - wordProd;
    if ( index != lastIndex ) {
        uNegDist = -dist;
        borrow = (wordShiftedRem < wordProd);
        for (;;) {
            wordShiftedRem = wordRem>>(uNegDist & 31);
            index += wordIncr;
            dwordProd = (uint64_t) bPtr[index] * q + (dwordProd>>32);
            wordRem = remPtr[index];
            wordShiftedRem |= wordRem<<dist;
            wordProd = dwordProd;
            zPtr[index] = wordShiftedRem - wordProd - borrow;
            if ( index == lastIndex ) break;
            borrow =
                borrow ? (wordShiftedRem <= wordProd)
                    : (wordShiftedRem < wordProd);
        }
    }

}

#endif

