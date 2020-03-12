#include "time32.h"
#include <time.h>
#include <sys/stat.h>

int __utimensat_time32(int fd, const char *path, const struct timespec32 times32[2], int flags)
{
	return utimensat(fd, path, !times32 ? 0 : ((struct timespec[2]){
		{.tv_sec = times32[0].tv_sec,.tv_nsec = times32[0].tv_nsec},
		{.tv_sec = times32[1].tv_sec,.tv_nsec = times32[1].tv_nsec}}),
		flags);
}
