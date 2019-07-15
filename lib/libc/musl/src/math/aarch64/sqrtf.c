#include <math.h>

float sqrtf(float x)
{
	__asm__ ("fsqrt %s0, %s1" : "=w"(x) : "w"(x));
	return x;
}
