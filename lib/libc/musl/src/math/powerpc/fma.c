#include <math.h>

#ifdef _SOFT_FLOAT

#include "../fma.c"

#else

double fma(double x, double y, double z)
{
	__asm__("fmadd %0, %1, %2, %3" : "=d"(x) : "d"(x), "d"(y), "d"(z));
	return x;
}

#endif
