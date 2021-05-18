#include "time32.h"
#include <sys/time.h>
#include <errno.h>
#include <stdint.h>

int __gettimeofday_time32(struct timeval32 *tv32, void *tz)
{
	struct timeval tv;
	if (!tv32) return 0;
	int r = gettimeofday(&tv, 0);
	if (r) return r;
	if (tv.tv_sec < INT32_MIN || tv.tv_sec > INT32_MAX) {
		errno = EOVERFLOW;
		return -1;
	}
	tv32->tv_sec = tv.tv_sec;
	tv32->tv_usec = tv.tv_usec;
	return 0;
}
