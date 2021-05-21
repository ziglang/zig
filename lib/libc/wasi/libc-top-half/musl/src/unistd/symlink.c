#include <unistd.h>
#include <fcntl.h>
#include "syscall.h"

int symlink(const char *existing, const char *new)
{
#ifdef SYS_symlink
	return syscall(SYS_symlink, existing, new);
#else
	return syscall(SYS_symlinkat, existing, AT_FDCWD, new);
#endif
}
