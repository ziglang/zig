#include <math.h>

long double remquol(long double x, long double y, int *quo)
{
	signed char *cx = (void *)&x, *cy = (void *)&y;
	/* By ensuring that addresses of x and y cannot be discarded,
	 * this empty asm guides GCC into representing extraction of
	 * their sign bits as memory loads rather than making x and y
	 * not-address-taken internally and using bitfield operations,
	 * which in the end wouldn't work out, as extraction from FPU
	 * registers needs to go through memory anyway. This way GCC
	 * should manage to use incoming stack slots without spills. */
	__asm__ ("" :: "X"(cx), "X"(cy));

	long double t = x;
	unsigned fpsr;
	do __asm__ ("fprem1; fnstsw %%ax" : "+t"(t), "=a"(fpsr) : "u"(y));
	while (fpsr & 0x400);
	/* C0, C1, C3 flags in x87 status word carry low bits of quotient:
	 * 15 14 13 12 11 10  9  8
	 *  . C3  .  .  . C2 C1 C0
	 *  . b1  .  .  .  0 b0 b2 */
	unsigned char i = fpsr >> 8;
	i = i>>4 | i<<4;
	/* i[5:2] is now {b0 b2 ? b1}. Retrieve {0 b2 b1 b0} via
	 * in-register table lookup. */
	unsigned qbits = 0x7575313164642020 >> (i & 60);
	qbits &= 7;

	*quo = (cx[9]^cy[9]) < 0 ? -qbits : qbits;
	return t;
}
