#include <math.h>

long lrint(double x)
{
	long r;
	__asm__ ("fistpl %0" : "=m"(r) : "t"(x) : "st");
	return r;
}
