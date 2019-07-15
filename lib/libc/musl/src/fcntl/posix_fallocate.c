#include <fcntl.h>
#include "syscall.h"

int posix_fallocate(int fd, off_t base, off_t len)
{
	return -__syscall(SYS_fallocate, fd, 0, __SYSCALL_LL_E(base),
		__SYSCALL_LL_E(len));
}

weak_alias(posix_fallocate, posix_fallocate64);
