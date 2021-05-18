#include <math.h>

long lrintf(float x)
{
	long n;
	__asm__ (
		"frintx %s1, %s1\n"
		"fcvtzs %x0, %s1\n" : "=r"(n), "+w"(x));
	return n;
}
