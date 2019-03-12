#define _GNU_SOURCE
#include <fcntl.h>
#include <errno.h>
#include "syscall.h"

int sync_file_range(int fd, off_t pos, off_t len, unsigned flags)
{
#if defined(SYS_sync_file_range2)
	return syscall(SYS_sync_file_range2, fd, flags,
		__SYSCALL_LL_E(pos), __SYSCALL_LL_E(len));
#elif defined(SYS_sync_file_range)
	return syscall(SYS_sync_file_range, fd,
		__SYSCALL_LL_O(pos), __SYSCALL_LL_E(len), flags);
#else
	return __syscall_ret(-ENOSYS);
#endif
}
