#include <math.h>

long lround(double x)
{
	long n;
	__asm__ ("fcvtas %x0, %d1" : "=r"(n) : "w"(x));
	return n;
}
