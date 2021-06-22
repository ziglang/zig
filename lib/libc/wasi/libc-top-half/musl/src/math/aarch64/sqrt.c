#include <math.h>

double sqrt(double x)
{
	__asm__ ("fsqrt %d0, %d1" : "=w"(x) : "w"(x));
	return x;
}
