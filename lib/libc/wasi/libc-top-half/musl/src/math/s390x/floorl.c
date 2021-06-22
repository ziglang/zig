#include <math.h>

#if defined(__HTM__) || __ARCH__ >= 9

long double floorl(long double x)
{
	__asm__ ("fixbra %0, 7, %1, 4" : "=f"(x) : "f"(x));
	return x;
}

#else

#include "../floorl.c"

#endif
