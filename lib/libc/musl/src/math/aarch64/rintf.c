#include <math.h>

float rintf(float x)
{
	__asm__ ("frintx %s0, %s1" : "=w"(x) : "w"(x));
	return x;
}
