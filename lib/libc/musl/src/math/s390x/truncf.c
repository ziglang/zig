#include <math.h>

#if defined(__HTM__) || __ARCH__ >= 9

float truncf(float x)
{
	__asm__ ("fiebra %0, 5, %1, 4" : "=f"(x) : "f"(x));
	return x;
}

#else

#include "../truncf.c"

#endif
