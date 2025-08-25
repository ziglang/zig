#include <math.h>

long long llrint(double x)
{
	long long r;
	__asm__ ("cvtsd2si %1, %0" : "=r"(r) : "x"(x));
	return r;
}
