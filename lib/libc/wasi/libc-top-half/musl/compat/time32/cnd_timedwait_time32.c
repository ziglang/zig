#include "time32.h"
#include <time.h>
#include <threads.h>

int __cnd_timedwait_time32(cnd_t *restrict c, mtx_t *restrict m, const struct timespec32 *restrict ts32)
{
	return cnd_timedwait(c, m, ts32 ? (&(struct timespec){
		.tv_sec = ts32->tv_sec, .tv_nsec = ts32->tv_nsec}) : 0);
}
