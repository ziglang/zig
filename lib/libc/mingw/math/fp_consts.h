/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _FP_CONSTS_H
#define _FP_CONSTS_H

/*
According to IEEE 754 a QNaN has exponent bits of all 1 values and
initial significand bit of 1.  A SNaN has has an exponent of all 1
values and initial significand bit of 0 (with one or more other
significand bits of 1). An Inf has significand of 0 and
exponent of all 1 values. A denormal value has all exponent bits of 0.

The following does _not_ follow those rules, but uses values
equal to those exported from MS C++ runtime lib, msvcprt.dll
for float and double. MSVC however, does not have long doubles.
*/


#define __DOUBLE_INF_REP { 0, 0, 0, 0x7ff0 }
#define __DOUBLE_QNAN_REP { 0, 0, 0, 0xfff8 }  /* { 0, 0, 0, 0x7ff8 }  */
#define __DOUBLE_SNAN_REP { 0, 0, 0, 0xfff0 }  /* { 1, 0, 0, 0x7ff0 }  */
#define __DOUBLE_DENORM_REP {1, 0, 0, 0}

#define D_NAN_MASK 0x7ff0000000000000LL /* this will mask NaN's and Inf's */

#define __FLOAT_INF_REP { 0, 0x7f80 }
#define __FLOAT_QNAN_REP { 0, 0xffc0 }  /* { 0, 0x7fc0 }  */
#define __FLOAT_SNAN_REP { 0, 0xff80 }  /* { 1, 0x7f80 }  */
#define __FLOAT_DENORM_REP {1,0}

#define F_NAN_MASK 0x7f800000

/*
   This assumes no implicit (hidden) bit in extended mode.
   Padded to 96 bits
 */
#define __LONG_DOUBLE_INF_REP { 0, 0, 0, 0x8000, 0x7fff, 0 }
#define __LONG_DOUBLE_QNAN_REP { 0, 0, 0, 0xc000, 0xffff, 0 }
#define __LONG_DOUBLE_SNAN_REP { 0, 0, 0, 0x8000, 0xffff, 0 }
#define __LONG_DOUBLE_DENORM_REP {1, 0, 0, 0, 0, 0}

union _ieee_rep
{
	unsigned short rep[6];
	float float_val;
	double double_val;
	long double ldouble_val;
};

#endif	/* _FP_CONSTS_H */

