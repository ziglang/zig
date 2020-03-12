#include "time32.h"
#include <time.h>
#include <pthread.h>

int __pthread_mutex_timedlock_time32(pthread_mutex_t *restrict m, const struct timespec32 *restrict ts32)
{
	return pthread_mutex_timedlock(m, !ts32 ? 0 : (&(struct timespec){
		.tv_sec = ts32->tv_sec, .tv_nsec = ts32->tv_nsec}));
}
