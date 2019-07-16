#include <math.h>

#if defined(__HTM__) || __ARCH__ >= 9

float ceilf(float x)
{
	__asm__ ("fiebra %0, 6, %1, 4" : "=f"(x) : "f"(x));
	return x;
}

#else

#include "../ceilf.c"

#endif
