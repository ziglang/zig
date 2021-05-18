#include <math.h>

#if __HAVE_68881__

long double sqrtl(long double x)
{
	__asm__ ("fsqrt.x %1,%0" : "=f"(x) : "fm"(x));
	return x;
}

#else

#include "../sqrtl.c"

#endif
