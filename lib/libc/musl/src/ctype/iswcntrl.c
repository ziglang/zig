#include <wctype.h>

int iswcntrl(wint_t wc)
{
	return (unsigned)wc < 32
	    || (unsigned)(wc-0x7f) < 33
	    || (unsigned)(wc-0x2028) < 2
	    || (unsigned)(wc-0xfff9) < 3;
}

int __iswcntrl_l(wint_t c, locale_t l)
{
	return iswcntrl(c);
}

weak_alias(__iswcntrl_l, iswcntrl_l);
