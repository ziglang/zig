#include <math.h>

double fma(double x, double y, double z)
{
	__asm__ ("madbr %0, %1, %2" : "+f"(z) : "f"(x), "f"(y));
	return z;
}
