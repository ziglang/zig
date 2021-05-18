#include <math.h>

#if defined(__HTM__) || __ARCH__ >= 9

long double sqrtl(long double x)
{
	__asm__ ("sqxbr %0, %1" : "=f"(x) : "f"(x));
	return x;
}

#else

#include "../sqrtl.c"

#endif
