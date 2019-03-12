#include <unistd.h>
#include "syscall.h"

ssize_t pread(int fd, void *buf, size_t size, off_t ofs)
{
	return syscall_cp(SYS_pread, fd, buf, size, __SYSCALL_LL_PRW(ofs));
}

weak_alias(pread, pread64);
