#include <math.h>

#if defined(__HTM__) || __ARCH__ >= 9

float floorf(float x)
{
	__asm__ ("fiebra %0, 7, %1, 4" : "=f"(x) : "f"(x));
	return x;
}

#else

#include "../floorf.c"

#endif
