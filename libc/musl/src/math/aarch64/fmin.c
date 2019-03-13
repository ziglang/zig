#include <math.h>

double fmin(double x, double y)
{
	__asm__ ("fminnm %d0, %d1, %d2" : "=w"(x) : "w"(x), "w"(y));
	return x;
}
