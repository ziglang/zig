#include <math.h>

long long llrint(double x)
{
	long long r;
	__asm__ ("fistpll %0" : "=m"(r) : "t"(x) : "st");
	return r;
}
