#include "time32.h"
#include <time.h>
#include <threads.h>
#include <errno.h>

int __thrd_sleep_time32(const struct timespec32 *req32, struct timespec32 *rem32)
{
	struct timespec rem;
	int ret = thrd_sleep((&(struct timespec){
		.tv_sec = req32->tv_sec, .tv_nsec = req32->tv_nsec}), &rem);
	if (ret<0 && errno==EINTR && rem32) {
		rem32->tv_sec = rem.tv_sec;
		rem32->tv_nsec = rem.tv_nsec;
	}
	return ret;
}
