#include "stdio_impl.h"
#include <string.h>

static size_t string_read(FILE *f, unsigned char *buf, size_t len)
{
	char *src = f->cookie;
	size_t k = len+256;
	char *end = memchr(src, 0, k);
	if (end) k = end-src;
	if (k < len) len = k;
	memcpy(buf, src, len);
	f->rpos = (void *)(src+len);
	f->rend = (void *)(src+k);
	f->cookie = src+k;
	return len;
}

int vsscanf(const char *restrict s, const char *restrict fmt, va_list ap)
{
	FILE f = {
		.buf = (void *)s, .cookie = (void *)s,
#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
		.read = string_read, .lock = -1
#else
		.read = string_read
#endif
	};
	return vfscanf(&f, fmt, ap);
}

weak_alias(vsscanf,__isoc99_vsscanf);
