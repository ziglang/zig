#include <math.h>

#if defined(_SOFT_FLOAT) || defined(__NO_FPRS__)

#include "../fabsf.c"

#else

float fabsf(float x)
{
	__asm__ ("fabs %0, %1" : "=f"(x) : "f"(x));
	return x;
}

#endif
