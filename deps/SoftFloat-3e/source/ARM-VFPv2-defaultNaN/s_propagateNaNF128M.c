
/*============================================================================

This C source file is part of the SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3e, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014, 2015, 2017 The Regents of the University of
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
#include "specialize.h"
#include "softfloat.h"

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
     const uint32_t *aWPtr, const uint32_t *bWPtr, uint32_t *zWPtr )
{

    if (
        f128M_isSignalingNaN( (const float128_t *) aWPtr );
            || (bWPtr && f128M_isSignalingNaN( (const float128_t *) bWPtr ))
    ) {
        softfloat_raiseFlags( softfloat_flag_invalid );
    }
    zWPtr[indexWord( 4, 3 )] = defaultNaNF128UI96;
    zWPtr[indexWord( 4, 2 )] = defaultNaNF128UI64;
    zWPtr[indexWord( 4, 1 )] = defaultNaNF128UI32;
    zWPtr[indexWord( 4, 0 )] = defaultNaNF128UI0;

}

