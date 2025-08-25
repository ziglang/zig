#include "stdio_impl.h"
#include <wchar.h>

static size_t wstring_read(FILE *f, unsigned char *buf, size_t len)
{
	const wchar_t *src = f->cookie;
	size_t k;

	if (!src) return 0;

	k = wcsrtombs((void *)f->buf, &src, f->buf_size, 0);
	if (k==(size_t)-1) {
		f->rpos = f->rend = 0;
		return 0;
	}

	f->rpos = f->buf;
	f->rend = f->buf + k;
	f->cookie = (void *)src;

	if (!len || !k) return 0;

	*buf = *f->rpos++;
	return 1;
}

int vswscanf(const wchar_t *restrict s, const wchar_t *restrict fmt, va_list ap)
{
	unsigned char buf[256];
	FILE f = {
		.buf = buf, .buf_size = sizeof buf,
		.cookie = (void *)s,
		.read = wstring_read, .lock = -1
	};
	return vfwscanf(&f, fmt, ap);
}

weak_alias(vswscanf,__isoc99_vswscanf);
