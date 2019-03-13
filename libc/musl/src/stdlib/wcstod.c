#include "shgetc.h"
#include "floatscan.h"
#include "stdio_impl.h"
#include <wchar.h>
#include <wctype.h>

/* This read function heavily cheats. It knows:
 *  (1) len will always be 1
 *  (2) non-ascii characters don't matter */

static size_t do_read(FILE *f, unsigned char *buf, size_t len)
{
	size_t i;
	const wchar_t *wcs = f->cookie;

	if (!wcs[0]) wcs=L"@";
	for (i=0; i<f->buf_size && wcs[i]; i++)
		f->buf[i] = wcs[i] < 128 ? wcs[i] : '@';
	f->rpos = f->buf;
	f->rend = f->buf + i;
	f->cookie = (void *)(wcs+i);

	if (i && len) {
		*buf = *f->rpos++;
		return 1;
	}
	return 0;
}

static long double wcstox(const wchar_t *s, wchar_t **p, int prec)
{
	wchar_t *t = (wchar_t *)s;
	unsigned char buf[64];
	FILE f = {0};
	f.flags = 0;
	f.rpos = f.rend = 0;
	f.buf = buf + 4;
	f.buf_size = sizeof buf - 4;
	f.lock = -1;
	f.read = do_read;
	while (iswspace(*t)) t++;
	f.cookie = (void *)t;
	shlim(&f, 0);
	long double y = __floatscan(&f, prec, 1);
	if (p) {
		size_t cnt = shcnt(&f);
		*p = cnt ? t + cnt : (wchar_t *)s;
	}
	return y;
}

float wcstof(const wchar_t *restrict s, wchar_t **restrict p)
{
	return wcstox(s, p, 0);
}

double wcstod(const wchar_t *restrict s, wchar_t **restrict p)
{
	return wcstox(s, p, 1);
}

long double wcstold(const wchar_t *restrict s, wchar_t **restrict p)
{
	return wcstox(s, p, 2);
}
