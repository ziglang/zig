#include <math.h>

long long llroundf(float x)
{
	long long n;
	__asm__ ("fcvtas %x0, %s1" : "=r"(n) : "w"(x));
	return n;
}
