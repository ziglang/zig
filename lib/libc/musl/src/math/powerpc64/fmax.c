#include <math.h>

#ifdef __VSX__

double fmax(double x, double y)
{
	__asm__ ("xsmaxdp %x0, %x1, %x2" : "=ws"(x) : "ws"(x), "ws"(y));
	return x;
}

#else

#include "../fmax.c"

#endif
