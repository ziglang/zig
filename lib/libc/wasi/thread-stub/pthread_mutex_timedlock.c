#include "pthread_impl.h"

int __pthread_mutex_timedlock(pthread_mutex_t *restrict m, const struct timespec *restrict at)
{
	/* "The pthread_mutex_timedlock() function may fail if: A deadlock condition was detected." */
	/* This means that we don't have to wait and then return timeout, we can just detect deadlock. */
	return pthread_mutex_lock(m);
}

weak_alias(__pthread_mutex_timedlock, pthread_mutex_timedlock);
