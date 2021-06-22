#include <math.h>

long lrint(double x)
{
	long r;
	__asm__ ("cvtsd2si %1, %0" : "=r"(r) : "x"(x));
	return r;
}
