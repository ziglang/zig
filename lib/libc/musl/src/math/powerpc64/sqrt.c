#include <math.h>

double sqrt(double x)
{
	__asm__ ("fsqrt %0, %1" : "=d"(x) : "d"(x));
	return x;
}
