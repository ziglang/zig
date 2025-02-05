#include <math.h>

#if __riscv_flen >= 32

float fmaf(float x, float y, float z)
{
	__asm__ ("fmadd.s %0, %1, %2, %3" : "=f"(x) : "f"(x), "f"(y), "f"(z));
	return x;
}

#else

#include "../fmaf.c"

#endif
