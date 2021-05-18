#include <math.h>

float fmaf(float x, float y, float z)
{
	__asm__ ("maebr %0, %1, %2" : "+f"(z) : "f"(x), "f"(y));
	return z;
}
