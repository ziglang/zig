#include <math.h>

long double fabsl(long double x)
{
	__asm__ ("fabs" : "+t"(x));
	return x;
}
