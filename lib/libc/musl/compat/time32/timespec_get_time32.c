#include "time32.h"
#include <time.h>
#include <errno.h>
#include <stdint.h>

int __timespec_get_time32(struct timespec32 *ts32, int base)
{
	struct timespec ts;
	int r = timespec_get(&ts, base);
	if (!r) return r;
	if (ts.tv_sec < INT32_MIN || ts.tv_sec > INT32_MAX) {
		errno = EOVERFLOW;
		return 0;
	}
	ts32->tv_sec = ts.tv_sec;
	ts32->tv_nsec = ts.tv_nsec;
	return r;
}
