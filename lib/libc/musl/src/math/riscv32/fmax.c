#include <math.h>

#if __riscv_flen >= 64

double fmax(double x, double y)
{
	__asm__ ("fmax.d %0, %1, %2" : "=f"(x) : "f"(x), "f"(y));
	return x;
}

#else

#include "../fmax.c"

#endif
