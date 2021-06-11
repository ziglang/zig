#include <math.h>

double fma(double x, double y, double z)
{
	__asm__ ("fmadd %d0, %d1, %d2, %d3" : "=w"(x) : "w"(x), "w"(y), "w"(z));
	return x;
}
