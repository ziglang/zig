#include <math.h>

#if (__ARM_PCS_VFP || (__VFP_FP__ && !__SOFTFP__)) && !BROKEN_VFP_ASM

float sqrtf(float x)
{
	__asm__ ("vsqrt.f32 %0, %1" : "=t"(x) : "t"(x));
	return x;
}

#else

#include "../sqrtf.c"

#endif
