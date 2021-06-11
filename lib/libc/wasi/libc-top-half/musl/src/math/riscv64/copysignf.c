#include <math.h>

#if __riscv_flen >= 32

float copysignf(float x, float y)
{
	__asm__ ("fsgnj.s %0, %1, %2" : "=f"(x) : "f"(x), "f"(y));
	return x;
}

#else

#include "../copysignf.c"

#endif
