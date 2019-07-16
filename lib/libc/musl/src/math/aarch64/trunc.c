#include <math.h>

double trunc(double x)
{
	__asm__ ("frintz %d0, %d1" : "=w"(x) : "w"(x));
	return x;
}
