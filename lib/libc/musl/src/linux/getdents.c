#define _BSD_SOURCE
#include <dirent.h>
#include <limits.h>
#include "syscall.h"

int getdents(int fd, struct dirent *buf, size_t len)
{
	if (len>INT_MAX) len = INT_MAX;
	return syscall(SYS_getdents, fd, buf, len);
}
