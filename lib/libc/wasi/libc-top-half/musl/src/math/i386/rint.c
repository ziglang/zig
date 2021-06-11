#include <math.h>

double rint(double x)
{
	__asm__ ("frndint" : "+t"(x));
	return x;
}
