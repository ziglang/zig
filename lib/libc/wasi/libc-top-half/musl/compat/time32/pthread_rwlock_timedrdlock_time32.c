#include "time32.h"
#include <time.h>
#include <pthread.h>

int __pthread_rwlock_timedrdlock_time32(pthread_rwlock_t *restrict rw, const struct timespec32 *restrict ts32)
{
	return pthread_rwlock_timedrdlock(rw, !ts32 ? 0 : (&(struct timespec){
		.tv_sec = ts32->tv_sec, .tv_nsec = ts32->tv_nsec}));
}
