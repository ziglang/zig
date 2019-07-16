#include "stdio_impl.h"
#include <errno.h>
#include <limits.h>
#include <string.h>
#include <stdlib.h>
#include "libc.h"

struct cookie {
	char **bufp;
	size_t *sizep;
	size_t pos;
	char *buf;
	size_t len;
	size_t space;
};

struct ms_FILE {
	FILE f;
	struct cookie c;
	unsigned char buf[BUFSIZ];
};

static off_t ms_seek(FILE *f, off_t off, int whence)
{
	ssize_t base;
	struct cookie *c = f->cookie;
	if (whence>2U) {
fail:
		errno = EINVAL;
		return -1;
	}
	base = (size_t [3]){0, c->pos, c->len}[whence];
	if (off < -base || off > SSIZE_MAX-base) goto fail;
	return c->pos = base+off;
}

static size_t ms_write(FILE *f, const unsigned char *buf, size_t len)
{
	struct cookie *c = f->cookie;
	size_t len2 = f->wpos - f->wbase;
	char *newbuf;
	if (len2) {
		f->wpos = f->wbase;
		if (ms_write(f, f->wbase, len2) < len2) return 0;
	}
	if (len + c->pos >= c->space) {
		len2 = 2*c->space+1 | c->pos+len+1;
		newbuf = realloc(c->buf, len2);
		if (!newbuf) return 0;
		*c->bufp = c->buf = newbuf;
		memset(c->buf + c->space, 0, len2 - c->space);
		c->space = len2;
	}
	memcpy(c->buf+c->pos, buf, len);
	c->pos += len;
	if (c->pos >= c->len) c->len = c->pos;
	*c->sizep = c->pos;
	return len;
}

static int ms_close(FILE *f)
{
	return 0;
}

FILE *open_memstream(char **bufp, size_t *sizep)
{
	struct ms_FILE *f;
	char *buf;

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
	f->f.buf_size = sizeof f->buf;
	f->f.lbf = EOF;
	f->f.write = ms_write;
	f->f.seek = ms_seek;
	f->f.close = ms_close;
	f->f.mode = -1;

	if (!libc.threaded) f->f.lock = -1;

	return __ofl_add(&f->f);
}
