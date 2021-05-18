#include <unistd.h>
#include <fcntl.h>
#include "syscall.h"

int rmdir(const char *path)
{
#ifdef SYS_rmdir
	return syscall(SYS_rmdir, path);
#else
	return syscall(SYS_unlinkat, AT_FDCWD, path, AT_REMOVEDIR);
#endif
}
