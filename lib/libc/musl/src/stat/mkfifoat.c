#include <sys/stat.h>

int mkfifoat(int fd, const char *path, mode_t mode)
{
	return mknodat(fd, path, mode | S_IFIFO, 0);
}
