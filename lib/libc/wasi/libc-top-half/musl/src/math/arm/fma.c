#include <math.h>

#if __ARM_FEATURE_FMA && __ARM_FP&8 && !__SOFTFP__

double fma(double x, double y, double z)
{
	__asm__ ("vfma.f64 %P0, %P1, %P2" : "+w"(z) : "w"(x), "w"(y));
	return z;
}

#else

#include "../fma.c"

#endif
