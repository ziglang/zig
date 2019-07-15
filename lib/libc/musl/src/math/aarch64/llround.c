#include <math.h>

long long llround(double x)
{
	long long n;
	__asm__ ("fcvtas %x0, %d1" : "=r"(n) : "w"(x));
	return n;
}
