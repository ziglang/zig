#include <math.h>

#if defined(__HTM__) || __ARCH__ >= 9

double sqrt(double x)
{
	__asm__ ("sqdbr %0, %1" : "=f"(x) : "f"(x));
	return x;
}

#else

#include "../sqrt.c"

#endif
