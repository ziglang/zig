#include "stdio_impl.h"
#include <fcntl.h>
#include <unistd.h>

/* The basic idea of this implementation is to open a new FILE,
 * hack the necessary parts of the new FILE into the old one, then
 * close the new FILE. */

/* Locking IS necessary because another thread may provably hold the
 * lock, via flockfile or otherwise, when freopen is called, and in that
 * case, freopen cannot act until the lock is released. */

FILE *freopen(const char *restrict filename, const char *restrict mode, FILE *restrict f)
{
	int fl = __fmodeflags(mode);
	FILE *f2;

	FLOCK(f);

	fflush(f);

	if (!filename) {
		if (fl&O_CLOEXEC)
			__syscall(SYS_fcntl, f->fd, F_SETFD, FD_CLOEXEC);
		fl &= ~(O_CREAT|O_EXCL|O_CLOEXEC);
		if (syscall(SYS_fcntl, f->fd, F_SETFL, fl) < 0)
			goto fail;
	} else {
		f2 = fopen(filename, mode);
		if (!f2) goto fail;
		if (f2->fd == f->fd) f2->fd = -1; /* avoid closing in fclose */
		else if (__dup3(f2->fd, f->fd, fl&O_CLOEXEC)<0) goto fail2;

		f->flags = (f->flags & F_PERM) | f2->flags;
		f->read = f2->read;
		f->write = f2->write;
		f->seek = f2->seek;
		f->close = f2->close;

		fclose(f2);
	}

	f->mode = 0;
	f->locale = 0;
	FUNLOCK(f);
	return f;

fail2:
	fclose(f2);
fail:
	fclose(f);
	return NULL;
}
