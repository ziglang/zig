#include "stdio_impl.h"
#include "locale_impl.h"
#include <wchar.h>
#include <errno.h>

static wint_t __fgetwc_unlocked_internal(FILE *f)
{
	wchar_t wc;
	int c;
	size_t l;

	/* Convert character from buffer if possible */
	if (f->rpos != f->rend) {
		l = mbtowc(&wc, (void *)f->rpos, f->rend - f->rpos);
		if (l+1 >= 1) {
			f->rpos += l + !l; /* l==0 means 1 byte, null */
			return wc;
		}
	}

	/* Convert character byte-by-byte */
	mbstate_t st = { 0 };
	unsigned char b;
	int first = 1;
	do {
		b = c = getc_unlocked(f);
		if (c < 0) {
			if (!first) {
				f->flags |= F_ERR;
				errno = EILSEQ;
			}
			return WEOF;
		}
		l = mbrtowc(&wc, (void *)&b, 1, &st);
		if (l == -1) {
			if (!first) {
				f->flags |= F_ERR;
				ungetc(b, f);
			}
			return WEOF;
		}
		first = 0;
	} while (l == -2);

	return wc;
}

wint_t __fgetwc_unlocked(FILE *f)
{
	locale_t *ploc = &CURRENT_LOCALE, loc = *ploc;
	if (f->mode <= 0) fwide(f, 1);
	*ploc = f->locale;
	wchar_t wc = __fgetwc_unlocked_internal(f);
	*ploc = loc;
	return wc;
}

wint_t fgetwc(FILE *f)
{
	wint_t c;
	FLOCK(f);
	c = __fgetwc_unlocked(f);
	FUNLOCK(f);
	return c;
}

weak_alias(__fgetwc_unlocked, fgetwc_unlocked);
weak_alias(__fgetwc_unlocked, getwc_unlocked);
