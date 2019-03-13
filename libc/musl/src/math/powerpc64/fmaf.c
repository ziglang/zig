#include <math.h>

float fmaf(float x, float y, float z)
{
	__asm__ ("fmadds %0, %1, %2, %3" : "=f"(x) : "f"(x), "f"(y), "f"(z));
	return x;
}
