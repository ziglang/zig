#include "stdio_impl.h"
#include <wchar.h>
#include <errno.h>
#include <limits.h>
#include <string.h>
#include <stdlib.h>
#include "libc.h"

struct cookie {
	wchar_t **bufp;
	size_t *sizep;
	size_t pos;
	wchar_t *buf;
	size_t len;
	size_t space;
	mbstate_t mbs;
};

struct wms_FILE {
	FILE f;
	struct cookie c;
	unsigned char buf[1];
};

static off_t wms_seek(FILE *f, off_t off, int whence)
{
	ssize_t base;
	struct cookie *c = f->cookie;
	if (whence>2U) {
fail:
		errno = EINVAL;
		return -1;
	}
#ifdef __wasilibc_unmodified_upstream // WASI's SEEK_* constants have different values.
	base = (size_t [3]){0, c->pos, c->len}[whence];
#else
	base = (size_t [3]) {
            [SEEK_SET] = 0,
            [SEEK_CUR] = c->pos,
            [SEEK_END] = c->len
        }[whence];
#endif
	if (off < -base || off > SSIZE_MAX/4-base) goto fail;
	memset(&c->mbs, 0, sizeof c->mbs);
	return c->pos = base+off;
}

static size_t wms_write(FILE *f, const unsigned char *buf, size_t len)
{
	struct cookie *c = f->cookie;
	size_t len2;
	wchar_t *newbuf;
	if (len + c->pos >= c->space) {
		len2 = 2*c->space+1 | c->pos+len+1;
		if (len2 > SSIZE_MAX/4) return 0;
		newbuf = realloc(c->buf, len2*4);
		if (!newbuf) return 0;
		*c->bufp = c->buf = newbuf;
		memset(c->buf + c->space, 0, 4*(len2 - c->space));
		c->space = len2;
	}
	
	len2 = mbsnrtowcs(c->buf+c->pos, (void *)&buf, len, c->space-c->pos, &c->mbs);
	if (len2 == -1) return 0;
	c->pos += len2;
	if (c->pos >= c->len) c->len = c->pos;
	*c->sizep = c->pos;
	return len;
}

static int wms_close(FILE *f)
{
	return 0;
}

FILE *open_wmemstream(wchar_t **bufp, size_t *sizep)
{
	struct wms_FILE *f;
	wchar_t *buf;

	if (!(f=malloc(sizeof *f))) return 0;
	if (!(buf=malloc(sizeof *buf))) {
		free(f);
		return 0;
	}
	memset(&f->f, 0, sizeof f->f);
	memset(&f->c, 0, sizeof f->c);
	f->f.cookie = &f->c;

	f->c.bufp = bufp;
	f->c.sizep = sizep;
	f->c.pos = f->c.len = f->c.space = *sizep = 0;
	f->c.buf = *bufp = buf;
	*buf = 0;

	f->f.flags = F_NORD;
	f->f.fd = -1;
	f->f.buf = f->buf;
	f->f.buf_size = 0;
	f->f.lbf = EOF;
	f->f.write = wms_write;
	f->f.seek = wms_seek;
	f->f.close = wms_close;

#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
	if (!libc.threaded) f->f.lock = -1;
#endif

	fwide(&f->f, 1);

	return __ofl_add(&f->f);
}
