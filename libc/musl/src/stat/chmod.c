#include <sys/stat.h>
#include <fcntl.h>
#include "syscall.h"

int chmod(const char *path, mode_t mode)
{
#ifdef SYS_chmod
	return syscall(SYS_chmod, path, mode);
#else
	return syscall(SYS_fchmodat, AT_FDCWD, path, mode);
#endif
}
