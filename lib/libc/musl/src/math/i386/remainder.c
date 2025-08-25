#include <math.h>

double remainder(double x, double y)
{
	unsigned short fpsr;
	// fprem1 does not introduce excess precision into x
	do __asm__ ("fprem1; fnstsw %%ax" : "+t"(x), "=a"(fpsr) : "u"(y));
	while (fpsr & 0x400);
	return x;
}

weak_alias(remainder, drem);
