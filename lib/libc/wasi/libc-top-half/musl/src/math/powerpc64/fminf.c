#include <math.h>

#ifdef __VSX__

float fminf(float x, float y)
{
	__asm__ ("xsmindp %x0, %x1, %x2" : "=ww"(x) : "ww"(x), "ww"(y));
	return x;
}

#else

#include "../fminf.c"

#endif
