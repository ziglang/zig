#include "time32.h"
#include <time.h>
#include <sys/time.h>
#include <sys/stat.h>

int __utimes_time32(const char *path, const struct timeval32 times32[2])
{
	return utimes(path, !times32 ? 0 : ((struct timeval[2]){
		{.tv_sec = times32[0].tv_sec,.tv_usec = times32[0].tv_usec},
		{.tv_sec = times32[1].tv_sec,.tv_usec = times32[1].tv_usec}}));
}
