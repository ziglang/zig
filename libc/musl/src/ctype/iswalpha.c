#include <wctype.h>

static const unsigned char table[] = {
#include "alpha.h"
};

int iswalpha(wint_t wc)
{
	if (wc<0x20000U)
		return (table[table[wc>>8]*32+((wc&255)>>3)]>>(wc&7))&1;
	if (wc<0x2fffeU)
		return 1;
	return 0;
}

int __iswalpha_l(wint_t c, locale_t l)
{
	return iswalpha(c);
}

weak_alias(__iswalpha_l, iswalpha_l);
