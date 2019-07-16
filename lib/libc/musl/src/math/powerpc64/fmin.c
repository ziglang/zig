#include <math.h>

#ifdef __VSX__

double fmin(double x, double y)
{
	__asm__ ("xsmindp %x0, %x1, %x2" : "=ws"(x) : "ws"(x), "ws"(y));
	return x;
}

#else

#include "../fmin.c"

#endif
