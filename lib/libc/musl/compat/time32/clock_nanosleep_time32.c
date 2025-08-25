#include "time32.h"
#include <time.h>
#include <errno.h>

int __clock_nanosleep_time32(clockid_t clk, int flags, const struct timespec32 *req32, struct timespec32 *rem32)
{
	struct timespec rem;
	int ret = clock_nanosleep(clk, flags, (&(struct timespec){
		.tv_sec = req32->tv_sec, .tv_nsec = req32->tv_nsec}), &rem);
	if (ret==EINTR && rem32 && !(flags & TIMER_ABSTIME)) {
		rem32->tv_sec = rem.tv_sec;
		rem32->tv_nsec = rem.tv_nsec;
	}
	return ret;
}
