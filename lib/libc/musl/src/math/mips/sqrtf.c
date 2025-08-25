#if !defined(__mips_soft_float) && __mips >= 2

#include <math.h>

float sqrtf(float x)
{
	float r;
	__asm__("sqrt.s %0,%1" : "=f"(r) : "f"(x));
	return r;
}

#else

#include "../sqrtf.c"

#endif
