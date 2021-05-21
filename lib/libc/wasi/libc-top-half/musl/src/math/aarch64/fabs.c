#include <math.h>

double fabs(double x)
{
	__asm__ ("fabs %d0, %d1" : "=w"(x) : "w"(x));
	return x;
}
