#include <math.h>

#if defined(__HTM__) || __ARCH__ >= 9

long double nearbyintl(long double x)
{
	__asm__ ("fixbra %0, 0, %1, 4" : "=f"(x) : "f"(x));
	return x;
}

#else

#include "../nearbyintl.c"

#endif
