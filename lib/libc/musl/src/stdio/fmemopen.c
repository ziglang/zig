#include "stdio_impl.h"
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <inttypes.h>
#include "libc.h"

struct cookie {
	size_t pos, len, size;
	unsigned char *buf;
	int mode;
};

struct mem_FILE {
	FILE f;
	struct cookie c;
	unsigned char buf[UNGET+BUFSIZ], buf2[];
};

static off_t mseek(FILE *f, off_t off, int whence)
{
	ssize_t base;
	struct cookie *c = f->cookie;
	if (whence>2U) {
fail:
		errno = EINVAL;
		return -1;
	}
	base = (size_t [3]){0, c->pos, c->len}[whence];
	if (off < -base || off > (ssize_t)c->size-base) goto fail;
	return c->pos = base+off;
}

static size_t mread(FILE *f, unsigned char *buf, size_t len)
{
	struct cookie *c = f->cookie;
	size_t rem = c->len - c->pos;
	if (c->pos > c->len) rem = 0;
	if (len > rem) {
		len = rem;
		f->flags |= F_EOF;
	}
	memcpy(buf, c->buf+c->pos, len);
	c->pos += len;
	rem -= len;
	if (rem > f->buf_size) rem = f->buf_size;
	f->rpos = f->buf;
	f->rend = f->buf + rem;
	memcpy(f->rpos, c->buf+c->pos, rem);
	c->pos += rem;
	return len;
}

static size_t mwrite(FILE *f, const unsigned char *buf, size_t len)
{
	struct cookie *c = f->cookie;
	size_t rem;
	size_t len2 = f->wpos - f->wbase;
	if (len2) {
		f->wpos = f->wbase;
		if (mwrite(f, f->wpos, len2) < len2) return 0;
	}
	if (c->mode == 'a') c->pos = c->len;
	rem = c->size - c->pos;
	if (len > rem) len = rem;
	memcpy(c->buf+c->pos, buf, len);
	c->pos += len;
	if (c->pos > c->len) {
		c->len = c->pos;
		if (c->len < c->size) c->buf[c->len] = 0;
		else if ((f->flags&F_NORD) && c->size) c->buf[c->size-1] = 0;
	}
	return len;
}

static int mclose(FILE *m)
{
	return 0;
}

FILE *fmemopen(void *restrict buf, size_t size, const char *restrict mode)
{
	struct mem_FILE *f;
	int plus = !!strchr(mode, '+');
	
	if (!strchr("rwa", *mode)) {
		errno = EINVAL;
		return 0;
	}

	if (!buf && size > PTRDIFF_MAX) {
		errno = ENOMEM;
		return 0;
	}

	f = malloc(sizeof *f + (buf?0:size));
	if (!f) return 0;
	memset(&f->f, 0, sizeof f->f);
	f->f.cookie = &f->c;
	f->f.fd = -1;
	f->f.lbf = EOF;
	f->f.buf = f->buf + UNGET;
	f->f.buf_size = sizeof f->buf - UNGET;
	if (!buf) {
		buf = f->buf2;;
		memset(buf, 0, size);
	}

	memset(&f->c, 0, sizeof f->c);
	f->c.buf = buf;
	f->c.size = size;
	f->c.mode = *mode;
	
	if (!plus) f->f.flags = (*mode == 'r') ? F_NOWR : F_NORD;
	if (*mode == 'r') f->c.len = size;
	else if (*mode == 'a') f->c.len = f->c.pos = strnlen(buf, size);
	else if (plus) *f->c.buf = 0;

	f->f.read = mread;
	f->f.write = mwrite;
	f->f.seek = mseek;
	f->f.close = mclose;

	if (!libc.threaded) f->f.lock = -1;

	return __ofl_add(&f->f);
}
