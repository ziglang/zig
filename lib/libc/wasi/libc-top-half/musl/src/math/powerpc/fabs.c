#include <math.h>

#if defined(_SOFT_FLOAT) || defined(BROKEN_PPC_D_ASM)

#include "../fabs.c"

#else

double fabs(double x)
{
	__asm__ ("fabs %0, %1" : "=d"(x) : "d"(x));
	return x;
}

#endif
