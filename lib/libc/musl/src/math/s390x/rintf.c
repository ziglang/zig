#include <math.h>

#if defined(__HTM__) || __ARCH__ >= 9

float rintf(float x)
{
	__asm__ ("fiebr %0, 0, %1" : "=f"(x) : "f"(x));
	return x;
}

#else

#include "../rintf.c"

#endif
