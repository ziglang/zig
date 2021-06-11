#define _GNU_SOURCE
#include "stdio_impl.h"
#include <stdlib.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>

struct fcookie {
	void *cookie;
	cookie_io_functions_t iofuncs;
};

struct cookie_FILE {
	FILE f;
	struct fcookie fc;
	unsigned char buf[UNGET+BUFSIZ];
};

static size_t cookieread(FILE *f, unsigned char *buf, size_t len)
{
	struct fcookie *fc = f->cookie;
	ssize_t ret = -1;
	size_t remain = len, readlen = 0;
	size_t len2 = len - !!f->buf_size;

	if (!fc->iofuncs.read) goto bail;

	if (len2) {
		ret = fc->iofuncs.read(fc->cookie, (char *) buf, len2);
		if (ret <= 0) goto bail;

		readlen += ret;
		remain -= ret;
	}

	if (!f->buf_size || remain > !!f->buf_size) return readlen;

	f->rpos = f->buf;
	ret = fc->iofuncs.read(fc->cookie, (char *) f->rpos, f->buf_size);
	if (ret <= 0) goto bail;
	f->rend = f->rpos + ret;

	buf[readlen++] = *f->rpos++;

	return readlen;

bail:
	f->flags |= ret == 0 ? F_EOF : F_ERR;
	f->rpos = f->rend = f->buf;
	return readlen;
}

static size_t cookiewrite(FILE *f, const unsigned char *buf, size_t len)
{
	struct fcookie *fc = f->cookie;
	ssize_t ret;
	size_t len2 = f->wpos - f->wbase;
	if (!fc->iofuncs.write) return len;
	if (len2) {
		f->wpos = f->wbase;
		if (cookiewrite(f, f->wpos, len2) < len2) return 0;
	}
	ret = fc->iofuncs.write(fc->cookie, (const char *) buf, len);
	if (ret < 0) {
		f->wpos = f->wbase = f->wend = 0;
		f->flags |= F_ERR;
		return 0;
	}
	return ret;
}

static off_t cookieseek(FILE *f, off_t off, int whence)
{
	struct fcookie *fc = f->cookie;
	int res;
	if (whence > 2U) {
		errno = EINVAL;
		return -1;
	}
	if (!fc->iofuncs.seek) {
		errno = ENOTSUP;
		return -1;
	}
	res = fc->iofuncs.seek(fc->cookie, &off, whence);
	if (res < 0)
		return res;
	return off;
}

static int cookieclose(FILE *f)
{
	struct fcookie *fc = f->cookie;
	if (fc->iofuncs.close) return fc->iofuncs.close(fc->cookie);
	return 0;
}

FILE *fopencookie(void *cookie, const char *mode, cookie_io_functions_t iofuncs)
{
	struct cookie_FILE *f;

	/* Check for valid initial mode character */
	if (!strchr("rwa", *mode)) {
		errno = EINVAL;
		return 0;
	}

	/* Allocate FILE+fcookie+buffer or fail */
	if (!(f=malloc(sizeof *f))) return 0;

	/* Zero-fill only the struct, not the buffer */
	memset(&f->f, 0, sizeof f->f);

	/* Impose mode restrictions */
	if (!strchr(mode, '+')) f->f.flags = (*mode == 'r') ? F_NOWR : F_NORD;

	/* Set up our fcookie */
	f->fc.cookie = cookie;
	f->fc.iofuncs = iofuncs;

	f->f.fd = -1;
	f->f.cookie = &f->fc;
	f->f.buf = f->buf + UNGET;
	f->f.buf_size = sizeof f->buf - UNGET;
	f->f.lbf = EOF;

	/* Initialize op ptrs. No problem if some are unneeded. */
	f->f.read = cookieread;
	f->f.write = cookiewrite;
	f->f.seek = cookieseek;
	f->f.close = cookieclose;

	/* Add new FILE to open file list */
	return __ofl_add(&f->f);
}
