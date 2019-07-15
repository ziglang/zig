#include <math.h>

#if defined(__HTM__) || __ARCH__ >= 9

float sqrtf(float x)
{
	__asm__ ("sqebr %0, %1" : "=f"(x) : "f"(x));
	return x;
}

#else

#include "../sqrtf.c"

#endif
