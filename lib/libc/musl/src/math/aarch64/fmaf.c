#include <math.h>

float fmaf(float x, float y, float z)
{
	__asm__ ("fmadd %s0, %s1, %s2, %s3" : "=w"(x) : "w"(x), "w"(y), "w"(z));
	return x;
}
