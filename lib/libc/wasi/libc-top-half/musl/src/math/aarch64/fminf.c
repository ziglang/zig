#include <math.h>

float fminf(float x, float y)
{
	__asm__ ("fminnm %s0, %s1, %s2" : "=w"(x) : "w"(x), "w"(y));
	return x;
}
