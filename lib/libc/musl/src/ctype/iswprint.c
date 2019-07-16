#include <wctype.h>

/* Consider all legal codepoints as printable except for:
 * - C0 and C1 control characters
 * - U+2028 and U+2029 (line/para break)
 * - U+FFF9 through U+FFFB (interlinear annotation controls)
 * The following code is optimized heavily to make hot paths for the
 * expected printable characters. */

int iswprint(wint_t wc)
{
	if (wc < 0xffU)
		return (wc+1 & 0x7f) >= 0x21;
	if (wc < 0x2028U || wc-0x202aU < 0xd800-0x202a || wc-0xe000U < 0xfff9-0xe000)
		return 1;
	if (wc-0xfffcU > 0x10ffff-0xfffc || (wc&0xfffe)==0xfffe)
		return 0;
	return 1;
}

int __iswprint_l(wint_t c, locale_t l)
{
	return iswprint(c);
}

weak_alias(__iswprint_l, iswprint_l);
