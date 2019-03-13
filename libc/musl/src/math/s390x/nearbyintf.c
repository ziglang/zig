#include <math.h>

#if defined(__HTM__) || __ARCH__ >= 9

float nearbyintf(float x)
{
	__asm__ ("fiebra %0, 0, %1, 4" : "=f"(x) : "f"(x));
	return x;
}

#else

#include "../nearbyintf.c"

#endif
