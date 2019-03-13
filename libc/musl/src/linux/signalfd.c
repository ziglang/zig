#include <sys/signalfd.h>
#include <signal.h>
#include <errno.h>
#include <fcntl.h>
#include "syscall.h"

int signalfd(int fd, const sigset_t *sigs, int flags)
{
	int ret = __syscall(SYS_signalfd4, fd, sigs, _NSIG/8, flags);
#ifdef SYS_signalfd
	if (ret != -ENOSYS) return __syscall_ret(ret);
	ret = __syscall(SYS_signalfd, fd, sigs, _NSIG/8);
	if (ret >= 0) {
		if (flags & SFD_CLOEXEC)
			__syscall(SYS_fcntl, ret, F_SETFD, FD_CLOEXEC);
		if (flags & SFD_NONBLOCK)
			__syscall(SYS_fcntl, ret, F_SETFL, O_NONBLOCK);
	}
#endif
	return __syscall_ret(ret);
}
