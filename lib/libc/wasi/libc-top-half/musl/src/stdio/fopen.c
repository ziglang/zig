#ifdef __wasilibc_unmodified_upstream // WASI has no syscall
#else
#include <unistd.h>
#include <wasi/libc.h>
#endif
#include "stdio_impl.h"
#include <fcntl.h>
#include <string.h>
#include <errno.h>

FILE *fopen(const char *restrict filename, const char *restrict mode)
{
	FILE *f;
	int fd;
	int flags;

	/* Check for valid initial mode character */
	if (!strchr("rwa", *mode)) {
		errno = EINVAL;
		return 0;
	}

	/* Compute the flags to pass to open() */
	flags = __fmodeflags(mode);

#ifdef __wasilibc_unmodified_upstream // WASI has no sys_open
	fd = sys_open(filename, flags, 0666);
#else
	// WASI libc ignores the mode parameter anyway, so skip the varargs.
	fd = __wasilibc_open_nomode(filename, flags);
#endif
	if (fd < 0) return 0;
#ifdef __wasilibc_unmodified_upstream // WASI has no syscall
	if (flags & O_CLOEXEC)
		__syscall(SYS_fcntl, fd, F_SETFD, FD_CLOEXEC);
#else
	/* Avoid __syscall, but also, FD_CLOEXEC is not supported in WASI. */
#endif

	f = __fdopen(fd, mode);
	if (f) return f;

#ifdef __wasilibc_unmodified_upstream // WASI has no syscall
	__syscall(SYS_close, fd);
#else
	close(fd);
#endif
	return 0;
}

weak_alias(fopen, fopen64);
