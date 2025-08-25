#include "time32.h"
#include <time.h>
#include <sched.h>

int __sched_rr_get_interval_time32(pid_t pid, struct timespec32 *ts32)
{
	struct timespec ts;
	int r = sched_rr_get_interval(pid, &ts);
	if (r) return r;
	ts32->tv_sec = ts.tv_sec;
	ts32->tv_nsec = ts.tv_nsec;
	return r;
}
