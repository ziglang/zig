#define _BSD_SOURCE
#include "time32.h"
#include <sys/time.h>

int __settimeofday_time32(const struct timeval32 *tv32, const void *tz)
{
	return settimeofday(!tv32 ? 0 : (&(struct timeval){
		.tv_sec = tv32->tv_sec,
		.tv_usec = tv32->tv_usec}), 0);
}
