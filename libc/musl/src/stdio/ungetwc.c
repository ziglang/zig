#include "stdio_impl.h"
#include "locale_impl.h"
#include <wchar.h>
#include <limits.h>
#include <ctype.h>
#include <string.h>

wint_t ungetwc(wint_t c, FILE *f)
{
	unsigned char mbc[MB_LEN_MAX];
	int l;
	locale_t *ploc = &CURRENT_LOCALE, loc = *ploc;

	FLOCK(f);

	if (f->mode <= 0) fwide(f, 1);
	*ploc = f->locale;

	if (!f->rpos) __toread(f);
	if (!f->rpos || c == WEOF || (l = wcrtomb((void *)mbc, c, 0)) < 0 ||
	    f->rpos < f->buf - UNGET + l) {
		FUNLOCK(f);
		*ploc = loc;
		return WEOF;
	}

	if (isascii(c)) *--f->rpos = c;
	else memcpy(f->rpos -= l, mbc, l);

	f->flags &= ~F_EOF;

	FUNLOCK(f);
	*ploc = loc;
	return c;
}
