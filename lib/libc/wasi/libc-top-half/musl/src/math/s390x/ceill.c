#include <math.h>

#if defined(__HTM__) || __ARCH__ >= 9

long double ceill(long double x)
{
	__asm__ ("fixbra %0, 6, %1, 4" : "=f"(x) : "f"(x));
	return x;
}

#else

#include "../ceill.c"

#endif
