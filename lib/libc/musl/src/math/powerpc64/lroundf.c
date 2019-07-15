#include <math.h>

#ifdef __VSX__

long lroundf(float x)
{
	long n;
	__asm__ (
		"xsrdpi %1, %1\n"
		"fctid %0, %1\n" : "=d"(n), "+f"(x));
	return n;
}

#else

#include "../lroundf.c"

#endif
