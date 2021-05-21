#include <math.h>

double floor(double x)
{
	__asm__ ("frintm %d0, %d1" : "=w"(x) : "w"(x));
	return x;
}
