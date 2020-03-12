#define _GNU_SOURCE
#include "time32.h"
#include <time.h>
#include <sys/time.h>
#include <sys/stat.h>

int __futimesat_time32(int dirfd, const char *pathname, const struct timeval32 times32[2])
{
	return futimesat(dirfd, pathname, !times32 ? 0 : ((struct timeval[2]){
		{.tv_sec = times32[0].tv_sec,.tv_usec = times32[0].tv_usec},
		{.tv_sec = times32[1].tv_sec,.tv_usec = times32[1].tv_usec}}));
}
