#include <math.h>

float rintf(float x)
{
	__asm__ ("frndint" : "+t"(x));
	return x;
}
