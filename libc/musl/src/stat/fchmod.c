#include <sys/stat.h>
#include <errno.h>
#include <fcntl.h>
#include "syscall.h"

int fchmod(int fd, mode_t mode)
{
	int ret = __syscall(SYS_fchmod, fd, mode);
	if (ret != -EBADF || __syscall(SYS_fcntl, fd, F_GETFD) < 0)
		return __syscall_ret(ret);

	char buf[15+3*sizeof(int)];
	__procfdname(buf, fd);
#ifdef SYS_chmod
	return syscall(SYS_chmod, buf, mode);
#else
	return syscall(SYS_fchmodat, AT_FDCWD, buf, mode);
#endif
}
