#include <math.h>

#ifdef __VSX__

float fmaxf(float x, float y)
{
	__asm__ ("xsmaxdp %x0, %x1, %x2" : "=ww"(x) : "ww"(x), "ww"(y));
	return x;
}

#else

#include "../fmaxf.c"

#endif
