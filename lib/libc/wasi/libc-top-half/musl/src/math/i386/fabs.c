#include <math.h>

double fabs(double x)
{
	__asm__ ("fabs" : "+t"(x));
	return x;
}
