#if !defined(__mips_soft_float) && defined(__mips_abs2008)

#include <math.h>

float fabsf(float x)
{
	float r;
	__asm__("abs.s %0,%1" : "=f"(r) : "f"(x));
	return r;
}

#else

#include "../fabsf.c"

#endif
