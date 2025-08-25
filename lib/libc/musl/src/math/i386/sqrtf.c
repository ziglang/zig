#include <math.h>

float sqrtf(float x)
{
	long double t;
	/* The long double result has sufficient precision so that
	 * second rounding to float still keeps the returned value
	 * correctly rounded, see Pierre Roux, "Innocuous Double
	 * Rounding of Basic Arithmetic Operations". */
	__asm__ ("fsqrt" : "=t"(t) : "0"(x));
	return (float)t;
}
