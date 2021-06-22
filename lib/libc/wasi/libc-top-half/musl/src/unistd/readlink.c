#include <unistd.h>
#include <fcntl.h>
#include "syscall.h"

ssize_t readlink(const char *restrict path, char *restrict buf, size_t bufsize)
{
	char dummy[1];
	if (!bufsize) {
		buf = dummy;
		bufsize = 1;
	}
#ifdef SYS_readlink
	int r = __syscall(SYS_readlink, path, buf, bufsize);
#else
	int r = __syscall(SYS_readlinkat, AT_FDCWD, path, buf, bufsize);
#endif
	if (buf == dummy && r > 0) r = 0;
	return __syscall_ret(r);
}
