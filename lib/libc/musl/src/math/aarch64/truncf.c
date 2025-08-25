#include <math.h>

float truncf(float x)
{
	__asm__ ("frintz %s0, %s1" : "=w"(x) : "w"(x));
	return x;
}
