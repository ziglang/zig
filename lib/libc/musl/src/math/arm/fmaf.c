#include <math.h>

#if __ARM_FEATURE_FMA && __ARM_FP&4 && !__SOFTFP__ && !BROKEN_VFP_ASM

float fmaf(float x, float y, float z)
{
	__asm__ ("vfma.f32 %0, %1, %2" : "+t"(z) : "t"(x), "t"(y));
	return z;
}

#else

#include "../fmaf.c"

#endif
