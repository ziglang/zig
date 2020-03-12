#include "time32.h"
#include <time.h>
#include <pthread.h>

int __pthread_cond_timedwait_time32(pthread_cond_t *restrict c, pthread_mutex_t *restrict m, const struct timespec32 *restrict ts32)
{
	return pthread_cond_timedwait(c, m, !ts32 ? 0 : (&(struct timespec){
		.tv_sec = ts32->tv_sec, .tv_nsec = ts32->tv_nsec}));
}
