#include <math.h>

float fabsf(float x)
{
	__asm__ ("fabs" : "+t"(x));
	return x;
}
