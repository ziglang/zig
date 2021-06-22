#include <math.h>

double nearbyint(double x)
{
	__asm__ ("frinti %d0, %d1" : "=w"(x) : "w"(x));
	return x;
}
