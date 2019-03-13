#include <math.h>

float sqrtf(float x)
{
	__asm__ ("fsqrts %0, %1" : "=f"(x) : "f"(x));
	return x;
}
