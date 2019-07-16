#include <math.h>

#if __riscv_flen >= 32

float fminf(float x, float y)
{
	__asm__ ("fmin.s %0, %1, %2" : "=f"(x) : "f"(x), "f"(y));
	return x;
}

#else

#include "../fminf.c"

#endif
