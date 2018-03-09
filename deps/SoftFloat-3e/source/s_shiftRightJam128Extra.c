
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

#ifndef softfloat_shiftRightJam128Extra

struct uint128_extra
 softfloat_shiftRightJam128Extra(
     uint64_t a64, uint64_t a0, uint64_t extra, uint_fast32_t dist )
{
    uint_fast8_t u8NegDist;
    struct uint128_extra z;

    u8NegDist = -dist;
    if ( dist < 64 ) {
        z.v.v64 = a64>>dist;
        z.v.v0 = a64<<(u8NegDist & 63) | a0>>dist;
        z.extra = a0<<(u8NegDist & 63);
    } else {
        z.v.v64 = 0;
        if ( dist == 64 ) {
            z.v.v0 = a64;
            z.extra = a0;
        } else {
            extra |= a0;
            if ( dist < 128 ) {
                z.v.v0 = a64>>(dist & 63);
                z.extra = a64<<(u8NegDist & 63);
            } else {
                z.v.v0 = 0;
                z.extra = (dist == 128) ? a64 : (a64 != 0);
            }
        }
    }
    z.extra |= (extra != 0);
    return z;

}

#endif

