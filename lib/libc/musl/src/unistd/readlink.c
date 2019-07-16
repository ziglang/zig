#include <unistd.h>
#include <fcntl.h>
#include "syscall.h"

ssize_t readlink(const char *restrict path, char *restrict buf, size_t bufsize)
{
#ifdef SYS_readlink
	return syscall(SYS_readlink, path, buf, bufsize);
#else
	return syscall(SYS_readlinkat, AT_FDCWD, path, buf, bufsize);
#endif
}
