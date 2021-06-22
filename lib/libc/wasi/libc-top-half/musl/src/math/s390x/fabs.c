#include <math.h>

#if defined(__HTM__) || __ARCH__ >= 9

double fabs(double x)
{
	__asm__ ("lpdbr %0, %1" : "=f"(x) : "f"(x));
	return x;
}

#else

#include "../fabs.c"

#endif
