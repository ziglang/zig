#include "time32.h"
#include <sys/stat.h>

struct stat32;

int __fxstat(int ver, int fd, struct stat32 *buf)
{
	return __fstat_time32(fd, buf);
}

int __fxstatat(int ver, int fd, const char *path, struct stat32 *buf, int flag)
{
	return __fstatat_time32(fd, path, buf, flag);
}

int __lxstat(int ver, const char *path, struct stat32 *buf)
{
	return __lstat_time32(path, buf);
}

int __xstat(int ver, const char *path, struct stat32 *buf)
{
	return __stat_time32(path, buf);
}
