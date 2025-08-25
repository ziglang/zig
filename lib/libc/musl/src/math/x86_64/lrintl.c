#include <math.h>

long lrintl(long double x)
{
	long r;
	__asm__ ("fistpll %0" : "=m"(r) : "t"(x) : "st");
	return r;
}
