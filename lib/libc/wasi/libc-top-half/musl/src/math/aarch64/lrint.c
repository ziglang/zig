#include <math.h>

long lrint(double x)
{
	long n;
	__asm__ (
		"frintx %d1, %d1\n"
		"fcvtzs %x0, %d1\n" : "=r"(n), "+w"(x));
	return n;
}
