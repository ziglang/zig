#define _GNU_SOURCE
#include <dirent.h>
#include <fcntl.h>
#include <stdlib.h>
#include "__dirent.h"
#include "syscall.h"

DIR *opendir(const char *name)
{
	int fd;
	DIR *dir;

	if ((fd = open(name, O_RDONLY|O_DIRECTORY|O_CLOEXEC)) < 0)
		return 0;
	if (!(dir = calloc(1, sizeof *dir))) {
		__syscall(SYS_close, fd);
		return 0;
	}
	dir->fd = fd;
	return dir;
}
