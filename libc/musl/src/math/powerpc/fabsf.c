#include <math.h>

#ifdef _SOFT_FLOAT

#include "../fabsf.c"

#else

float fabsf(float x)
{
	__asm__ ("fabs %0, %1" : "=f"(x) : "f"(x));
	return x;
}

#endif
