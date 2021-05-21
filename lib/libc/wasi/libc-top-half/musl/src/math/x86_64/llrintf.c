#include <math.h>

long long llrintf(float x)
{
	long long r;
	__asm__ ("cvtss2si %1, %0" : "=r"(r) : "x"(x));
	return r;
}
