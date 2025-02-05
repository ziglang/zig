#define _GNU_SOURCE
#include <sys/uio.h>
#include <unistd.h>
#include "syscall.h"

ssize_t pwritev2(int fd, const struct iovec *iov, int count, off_t ofs, int flags)
{
#ifdef SYS_pwritev
	if (!flags) {
		if (ofs==-1) return writev(fd, iov, count);
		return syscall_cp(SYS_pwritev, fd, iov, count,
			(long)(ofs), (long)(ofs>>32));
	}
#endif
	return syscall_cp(SYS_pwritev2, fd, iov, count,
		(long)(ofs), (long)(ofs>>32), flags);
}
