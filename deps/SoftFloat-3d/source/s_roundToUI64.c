
/*============================================================================

This C source file is part of the SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3d, by John R. Hauser.

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

#include <stdbool.h>
#include <stdint.h>
#include "platform.h"
#include "internals.h"
#include "specialize.h"
#include "softfloat.h"

uint_fast64_t
 softfloat_roundToUI64(
     bool sign,
     uint_fast64_t sig,
     uint_fast64_t sigExtra,
     uint_fast8_t roundingMode,
     bool exact
 )
{
    bool roundNearEven, doIncrement;

    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    roundNearEven = (roundingMode == softfloat_round_near_even);
    doIncrement = (UINT64_C( 0x8000000000000000 ) <= sigExtra);
    if ( ! roundNearEven && (roundingMode != softfloat_round_near_maxMag) ) {
        doIncrement =
            (roundingMode
                 == (sign ? softfloat_round_min : softfloat_round_max))
                && sigExtra;
    }
    if ( doIncrement ) {
        ++sig;
        if ( ! sig ) goto invalid;
        sig &=
            ~(uint_fast64_t)
                 (! (sigExtra & UINT64_C( 0x7FFFFFFFFFFFFFFF ))
                      & roundNearEven);
    }
    if ( sign && sig ) goto invalid;
    if ( exact && sigExtra ) {
        softfloat_exceptionFlags |= softfloat_flag_inexact;
    }
    return sig;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 invalid:
    softfloat_raiseFlags( softfloat_flag_invalid );
    return sign ? ui64_fromNegOverflow : ui64_fromPosOverflow;

}

