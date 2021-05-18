#include <math.h>

#ifdef __VSX__

long lround(double x)
{
	long n;
	__asm__ (
		"xsrdpi %1, %1\n"
		"fctid %0, %1\n" : "=d"(n), "+d"(x));
	return n;
}

#else

#include "../lround.c"

#endif
