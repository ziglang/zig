#include <stdio.h>
#include <fcntl.h>
#include "syscall.h"

int rename(const char *old, const char *new)
{
#if defined(SYS_rename)
	return syscall(SYS_rename, old, new);
#elif defined(SYS_renameat)
	return syscall(SYS_renameat, AT_FDCWD, old, AT_FDCWD, new);
#else
	return syscall(SYS_renameat2, AT_FDCWD, old, AT_FDCWD, new, 0);
#endif
}
