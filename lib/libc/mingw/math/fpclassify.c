/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#define __CRT__NO_INLINE
#include <math.h>

/* 'fxam' sets FPU flags C3,C2,C0   'fstsw' stores: 
 FP_NAN			001		0x0100
 FP_NORMAL		010		0x0400
 FP_INFINITE		011		0x0500
 FP_ZERO		100		0x4000
 FP_SUBNORMAL		110		0x4400

and sets C1 flag (signbit) if neg */

int __fpclassify (double _x)
{
    __mingw_dbl_type_t hlp;
    unsigned int l, h;

    hlp.x = _x;
    h = hlp.lh.high;
    l = hlp.lh.low | (h & 0xfffff);
    h &= 0x7ff00000;
    if ((h | l) == 0)
      return FP_ZERO;
    if (!h)
      return FP_SUBNORMAL;
    if (h == 0x7ff00000)
      return (l ? FP_NAN : FP_INFINITE);
    return FP_NORMAL;
}
