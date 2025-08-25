#include <stdlib.h>
#include <wchar.h>
#include <errno.h>
#include "internal.h"

size_t mbrtowc(wchar_t *restrict wc, const char *restrict src, size_t n, mbstate_t *restrict st)
{
	static unsigned internal_state;
	unsigned c;
	const unsigned char *s = (const void *)src;
	const size_t N = n;
	wchar_t dummy;

	if (!st) st = (void *)&internal_state;
	c = *(unsigned *)st;
	
	if (!s) {
		if (c) goto ilseq;
		return 0;
	} else if (!wc) wc = &dummy;

	if (!n) return -2;
	if (!c) {
		if (*s < 0x80) return !!(*wc = *s);
		if (MB_CUR_MAX==1) return (*wc = CODEUNIT(*s)), 1;
		if (*s-SA > SB-SA) goto ilseq;
		c = bittab[*s++-SA]; n--;
	}

	if (n) {
		if (OOB(c,*s)) goto ilseq;
loop:
		c = c<<6 | *s++-0x80; n--;
		if (!(c&(1U<<31))) {
			*(unsigned *)st = 0;
			*wc = c;
			return N-n;
		}
		if (n) {
			if (*s-0x80u >= 0x40) goto ilseq;
			goto loop;
		}
	}

	*(unsigned *)st = c;
	return -2;
ilseq:
	*(unsigned *)st = 0;
	errno = EILSEQ;
	return -1;
}
