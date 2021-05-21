#define _GNU_SOURCE
#include <unistd.h>
#include "syscall.h"

int syncfs(int fd)
{
	return syscall(SYS_syncfs, fd);
}
