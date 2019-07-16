#include <math.h>

#ifdef _ARCH_PWR5X

float ceilf(float x)
{
	__asm__ ("frip %0, %1" : "=f"(x) : "f"(x));
	return x;
}

#else

#include "../ceilf.c"

#endif
