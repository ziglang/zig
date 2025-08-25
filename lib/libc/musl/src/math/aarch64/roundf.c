#include <math.h>

float roundf(float x)
{
	__asm__ ("frinta %s0, %s1" : "=w"(x) : "w"(x));
	return x;
}
