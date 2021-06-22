#include "stdio_impl.h"
#include <stdlib.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include "libc.h"
#ifdef __wasilibc_unmodified_upstream // WASI has no syscall
#else
#include <__function___isatty.h>
#endif

FILE *__fdopen(int fd, const char *mode)
{
	FILE *f;
#ifdef __wasilibc_unmodified_upstream // WASI has no syscall
	struct winsize wsz;
#endif

	/* Check for valid initial mode character */
	if (!strchr("rwa", *mode)) {
		errno = EINVAL;
		return 0;
	}

	/* Allocate FILE+buffer or fail */
	if (!(f=malloc(sizeof *f + UNGET + BUFSIZ))) return 0;

	/* Zero-fill only the struct, not the buffer */
	memset(f, 0, sizeof *f);

	/* Impose mode restrictions */
	if (!strchr(mode, '+')) f->flags = (*mode == 'r') ? F_NOWR : F_NORD;

	/* Apply close-on-exec flag */
#ifdef __wasilibc_unmodified_upstream // WASI has no syscall
	if (strchr(mode, 'e')) __syscall(SYS_fcntl, fd, F_SETFD, FD_CLOEXEC);
#else
	if (strchr(mode, 'e')) fcntl(fd, F_SETFD, FD_CLOEXEC);
#endif

	/* Set append mode on fd if opened for append */
	if (*mode == 'a') {
#ifdef __wasilibc_unmodified_upstream // WASI has no syscall
		int flags = __syscall(SYS_fcntl, fd, F_GETFL);
#else
		int flags = fcntl(fd, F_GETFL);
#endif
		if (!(flags & O_APPEND))
#ifdef __wasilibc_unmodified_upstream // WASI has no syscall
			__syscall(SYS_fcntl, fd, F_SETFL, flags | O_APPEND);
#else
			fcntl(fd, F_SETFL, flags | O_APPEND);
#endif
		f->flags |= F_APP;
	}

	f->fd = fd;
	f->buf = (unsigned char *)f + sizeof *f + UNGET;
	f->buf_size = BUFSIZ;

	/* Activate line buffered mode for terminals */
	f->lbf = EOF;
#ifdef __wasilibc_unmodified_upstream // WASI has no syscall
	if (!(f->flags & F_NOWR) && !__syscall(SYS_ioctl, fd, TIOCGWINSZ, &wsz))
#else
	if (!(f->flags & F_NOWR) && __isatty(fd))
#endif
		f->lbf = '\n';

	/* Initialize op ptrs. No problem if some are unneeded. */
	f->read = __stdio_read;
	f->write = __stdio_write;
	f->seek = __stdio_seek;
	f->close = __stdio_close;

#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
	if (!libc.threaded) f->lock = -1;
#endif

	/* Add new FILE to open file list */
	return __ofl_add(f);
}

weak_alias(__fdopen, fdopen);
