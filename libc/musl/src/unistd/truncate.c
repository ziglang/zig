#include <unistd.h>
#include "syscall.h"

int truncate(const char *path, off_t length)
{
	return syscall(SYS_truncate, path, __SYSCALL_LL_O(length));
}

weak_alias(truncate, truncate64);
