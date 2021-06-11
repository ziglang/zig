#include <math.h>

#if __ARM_PCS_VFP && __ARM_FP&8

double fabs(double x)
{
	__asm__ ("vabs.f64 %P0, %P1" : "=w"(x) : "w"(x));
	return x;
}

#else

#include "../fabs.c"

#endif
