#define _GNU_SOURCE
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include "syscall.h"

int __dup3(int old, int new, int flags)
{
	int r;
#ifdef SYS_dup2
	if (old==new) return __syscall_ret(-EINVAL);
	if (flags) {
		while ((r=__syscall(SYS_dup3, old, new, flags))==-EBUSY);
		if (r!=-ENOSYS) return __syscall_ret(r);
		if (flags & ~O_CLOEXEC) return __syscall_ret(-EINVAL);
	}
	while ((r=__syscall(SYS_dup2, old, new))==-EBUSY);
	if (r >= 0 && (flags & O_CLOEXEC))
		__syscall(SYS_fcntl, new, F_SETFD, FD_CLOEXEC);
#else
	while ((r=__syscall(SYS_dup3, old, new, flags))==-EBUSY);
#endif
	return __syscall_ret(r);
}

weak_alias(__dup3, dup3);
