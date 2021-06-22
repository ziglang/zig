#include <math.h>

float sqrtf(float x)
{
	__asm__ ("sqrtss %1, %0" : "=x"(x) : "x"(x));
	return x;
}
