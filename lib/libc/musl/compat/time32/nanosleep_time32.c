#include "time32.h"
#include <time.h>
#include <errno.h>

int __nanosleep_time32(const struct timespec32 *req32, struct timespec32 *rem32)
{
	struct timespec rem;
	int ret = nanosleep((&(struct timespec){
		.tv_sec = req32->tv_sec, .tv_nsec = req32->tv_nsec}), &rem);
	if (ret<0 && errno==EINTR && rem32) {
		rem32->tv_sec = rem.tv_sec;
		rem32->tv_nsec = rem.tv_nsec;
	}
	return ret;
}
