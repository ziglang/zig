#include <math.h>

#ifdef _ARCH_PWR5X

long lrintf(float x)
{
	long n;
	__asm__ ("fctid %0, %1" : "=d"(n) : "f"(x));
	return n;
}

#else

#include "../lrintf.c"

#endif
