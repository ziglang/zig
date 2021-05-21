#include "stdio_impl.h"
#include <fcntl.h>
#include <string.h>

FILE *__fopen_rb_ca(const char *filename, FILE *f, unsigned char *buf, size_t len)
{
	memset(f, 0, sizeof *f);

#ifdef __wasilibc_unmodified_upstream // WASI has no sys_open
	f->fd = sys_open(filename, O_RDONLY|O_CLOEXEC);
#else
	f->fd = open(filename, O_RDONLY|O_CLOEXEC);
#endif
	if (f->fd < 0) return 0;
#ifdef __wasilibc_unmodified_upstream // WASI has no syscall
	__syscall(SYS_fcntl, f->fd, F_SETFD, FD_CLOEXEC);
#else
	fcntl(f->fd, F_SETFD, FD_CLOEXEC);
#endif

	f->flags = F_NOWR | F_PERM;
	f->buf = buf + UNGET;
	f->buf_size = len - UNGET;
	f->read = __stdio_read;
	f->seek = __stdio_seek;
	f->close = __stdio_close;
#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
	f->lock = -1;
#endif

	return f;
}
