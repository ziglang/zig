#include "stdio_impl.h"
#include <limits.h>
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <wchar.h>

struct cookie {
	wchar_t *ws;
	size_t l;
};

static size_t sw_write(FILE *f, const unsigned char *s, size_t l)
{
	size_t l0 = l;
	int i = 0;
	struct cookie *c = f->cookie;
	if (s!=f->wbase && sw_write(f, f->wbase, f->wpos-f->wbase)==-1)
		return -1;
	while (c->l && l && (i=mbtowc(c->ws, (void *)s, l))>=0) {
		s+=i;
		l-=i;
		c->l--;
		c->ws++;
	}
	*c->ws = 0;
	if (i < 0) {
		f->wpos = f->wbase = f->wend = 0;
		f->flags |= F_ERR;
		return i;
	}
	f->wend = f->buf + f->buf_size;
	f->wpos = f->wbase = f->buf;
	return l0;
}

int vswprintf(wchar_t *restrict s, size_t n, const wchar_t *restrict fmt, va_list ap)
{
	int r;
	unsigned char buf[256];
	struct cookie c = { s, n-1 };
	FILE f = {
		.lbf = EOF,
		.write = sw_write,
#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
		.lock = -1,
#endif
		.buf = buf,
		.buf_size = sizeof buf,
		.cookie = &c,
	};

	if (!n) {
		return -1;
	} else if (n > INT_MAX) {
		errno = EOVERFLOW;
		return -1;
	}
	r = vfwprintf(&f, fmt, ap);
	sw_write(&f, 0, 0);
	return r>=n ? -1 : r;
}
