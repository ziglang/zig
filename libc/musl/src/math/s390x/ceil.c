#include <math.h>

#if defined(__HTM__) || __ARCH__ >= 9

double ceil(double x)
{
	__asm__ ("fidbra %0, 6, %1, 4" : "=f"(x) : "f"(x));
	return x;
}

#else

#include "../ceil.c"

#endif
