#include <math.h>

#if __riscv_flen >= 64

double copysign(double x, double y)
{
	__asm__ ("fsgnj.d %0, %1, %2" : "=f"(x) : "f"(x), "f"(y));
	return x;
}

#else

#include "../copysign.c"

#endif
