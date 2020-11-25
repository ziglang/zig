#include <math.h>

double fabs(double x)
{
	double t;
	__asm__ ("pcmpeqd %0, %0" : "=x"(t));          // t = ~0
	__asm__ ("psrlq   $1, %0" : "+x"(t));          // t >>= 1
	__asm__ ("andps   %1, %0" : "+x"(x) : "x"(t)); // x &= t
	return x;
}
