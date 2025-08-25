#include <math.h>

double fmod(double x, double y)
{
	unsigned short fpsr;
	// fprem does not introduce excess precision into x
	do __asm__ ("fprem; fnstsw %%ax" : "+t"(x), "=a"(fpsr) : "u"(y));
	while (fpsr & 0x400);
	return x;
}
