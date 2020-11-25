#include <math.h>

long double fmodl(long double x, long double y)
{
	unsigned short fpsr;
	do __asm__ ("fprem; fnstsw %%ax" : "+t"(x), "=a"(fpsr) : "u"(y));
	while (fpsr & 0x400);
	return x;
}
