#include <sys/stat.h>
#include <fcntl.h>
#include "syscall.h"

int stat(const char *restrict path, struct stat *restrict buf)
{
#ifdef SYS_stat
	return syscall(SYS_stat, path, buf);
#else
	return syscall(SYS_fstatat, AT_FDCWD, path, buf, 0);
#endif
}

weak_alias(stat, stat64);
