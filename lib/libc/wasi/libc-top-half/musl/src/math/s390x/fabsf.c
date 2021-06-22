#include <math.h>

#if defined(__HTM__) || __ARCH__ >= 9

float fabsf(float x)
{
	__asm__ ("lpebr %0, %1" : "=f"(x) : "f"(x));
	return x;
}

#else

#include "../fabsf.c"

#endif
