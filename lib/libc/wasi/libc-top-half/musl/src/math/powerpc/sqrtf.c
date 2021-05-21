#include <math.h>

#if !defined _SOFT_FLOAT && defined _ARCH_PPCSQ

float sqrtf(float x)
{
	__asm__ ("fsqrts %0, %1\n" : "=f" (x) : "f" (x));
	return x;
}

#else

#include "../sqrtf.c"

#endif
