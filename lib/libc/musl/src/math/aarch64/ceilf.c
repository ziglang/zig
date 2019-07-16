#include <math.h>

float ceilf(float x)
{
	__asm__ ("frintp %s0, %s1" : "=w"(x) : "w"(x));
	return x;
}
