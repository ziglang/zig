#include <math.h>

#ifdef _ARCH_PWR5X

float roundf(float x)
{
	__asm__ ("frin %0, %1" : "=f"(x) : "f"(x));
	return x;
}

#else

#include "../roundf.c"

#endif
