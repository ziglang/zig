#include <math.h>

long lrintf(float x)
{
	long r;
	__asm__ ("cvtss2si %1, %0" : "=r"(r) : "x"(x));
	return r;
}
