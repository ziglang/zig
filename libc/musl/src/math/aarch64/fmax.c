#include <math.h>

double fmax(double x, double y)
{
	__asm__ ("fmaxnm %d0, %d1, %d2" : "=w"(x) : "w"(x), "w"(y));
	return x;
}
