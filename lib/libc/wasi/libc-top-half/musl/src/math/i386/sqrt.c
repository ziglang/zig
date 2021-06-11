#include "libm.h"

double sqrt(double x)
{
	union ldshape ux;
	unsigned fpsr;
	__asm__ ("fsqrt; fnstsw %%ax": "=t"(ux.f), "=a"(fpsr) : "0"(x));
	if ((ux.i.m & 0x7ff) != 0x400)
		return (double)ux.f;
	/* Rounding to double would have encountered an exact halfway case.
	   Adjust mantissa downwards if fsqrt rounded up, else upwards.
	   (result of fsqrt could not have been exact) */
	ux.i.m ^= (fpsr & 0x200) + 0x300;
	return (double)ux.f;
}
