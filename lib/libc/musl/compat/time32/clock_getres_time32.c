#include "time32.h"
#include <time.h>

int __clock_getres_time32(clockid_t clk, struct timespec32 *ts32)
{
	struct timespec ts;
	int r = clock_getres(clk, &ts);
	if (!r && ts32) {
		ts32->tv_sec = ts.tv_sec;
		ts32->tv_nsec = ts.tv_nsec;
	}
	return r;
}
