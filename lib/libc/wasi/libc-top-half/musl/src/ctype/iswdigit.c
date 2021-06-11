#include <wctype.h>

#undef iswdigit

int iswdigit(wint_t wc)
{
	return (unsigned)wc-'0' < 10;
}

int __iswdigit_l(wint_t c, locale_t l)
{
	return iswdigit(c);
}

weak_alias(__iswdigit_l, iswdigit_l);
