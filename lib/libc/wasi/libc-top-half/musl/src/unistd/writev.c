#include <sys/uio.h>
#include "syscall.h"

ssize_t writev(int fd, const struct iovec *iov, int count)
{
	return syscall_cp(SYS_writev, fd, iov, count);
}
