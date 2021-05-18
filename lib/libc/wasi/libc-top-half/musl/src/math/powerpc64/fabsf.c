#include <math.h>

float fabsf(float x)
{
	__asm__ ("fabs %0, %1" : "=f"(x) : "f"(x));
	return x;
}
