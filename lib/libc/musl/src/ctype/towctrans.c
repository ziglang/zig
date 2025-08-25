#include <wctype.h>

static const unsigned char tab[];

static const unsigned char rulebases[512];
static const int rules[];

static const unsigned char exceptions[][2];

#include "casemap.h"

static int casemap(unsigned c, int dir)
{
	unsigned b, x, y, v, rt, xb, xn;
	int r, rd, c0 = c;

	if (c >= 0x20000) return c;

	b = c>>8;
	c &= 255;
	x = c/3;
	y = c%3;

	/* lookup entry in two-level base-6 table */
	v = tab[tab[b]*86+x];
	static const int mt[] = { 2048, 342, 57 };
	v = (v*mt[y]>>11)%6;

	/* use the bit vector out of the tables as an index into
	 * a block-specific set of rules and decode the rule into
	 * a type and a case-mapping delta. */
	r = rules[rulebases[b]+v];
	rt = r & 255;
	rd = r >> 8;

	/* rules 0/1 are simple lower/upper case with a delta.
	 * apply according to desired mapping direction. */
	if (rt < 2) return c0 + (rd & -(rt^dir));

	/* binary search. endpoints of the binary search for
	 * this block are stored in the rule delta field. */
	xn = rd & 0xff;
	xb = (unsigned)rd >> 8;
	while (xn) {
		unsigned try = exceptions[xb+xn/2][0];
		if (try == c) {
			r = rules[exceptions[xb+xn/2][1]];
			rt = r & 255;
			rd = r >> 8;
			if (rt < 2) return c0 + (rd & -(rt^dir));
			/* Hard-coded for the four exceptional titlecase */
			return c0 + (dir ? -1 : 1);
		} else if (try > c) {
			xn /= 2;
		} else {
			xb += xn/2;
			xn -= xn/2;
		}
	}
	return c0;
}

wint_t towlower(wint_t wc)
{
	return casemap(wc, 0);
}

wint_t towupper(wint_t wc)
{
	return casemap(wc, 1);
}

wint_t __towupper_l(wint_t c, locale_t l)
{
	return towupper(c);
}

wint_t __towlower_l(wint_t c, locale_t l)
{
	return towlower(c);
}

weak_alias(__towupper_l, towupper_l);
weak_alias(__towlower_l, towlower_l);
