#include <math.h>

#if defined(__HTM__) || __ARCH__ >= 9

double rint(double x)
{
	__asm__ ("fidbr %0, 0, %1" : "=f"(x) : "f"(x));
	return x;
}

#else

#include "../rint.c"

#endif
