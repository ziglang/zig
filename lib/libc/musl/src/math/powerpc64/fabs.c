#include <math.h>

double fabs(double x)
{
	__asm__ ("fabs %0, %1" : "=d"(x) : "d"(x));
	return x;
}
