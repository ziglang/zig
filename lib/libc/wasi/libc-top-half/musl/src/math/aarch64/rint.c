#include <math.h>

double rint(double x)
{
	__asm__ ("frintx %d0, %d1" : "=w"(x) : "w"(x));
	return x;
}
