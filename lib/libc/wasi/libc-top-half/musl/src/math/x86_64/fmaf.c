#include <math.h>

#if __FMA__

float fmaf(float x, float y, float z)
{
	__asm__ ("vfmadd132ss %1, %2, %0" : "+x" (x) : "x" (y), "x" (z));
	return x;
}

#elif __FMA4__

float fmaf(float x, float y, float z)
{
	__asm__ ("vfmaddss %3, %2, %1, %0" : "=x" (x) : "x" (x), "x" (y), "x" (z));
	return x;
}

#else

#include "../fmaf.c"

#endif
