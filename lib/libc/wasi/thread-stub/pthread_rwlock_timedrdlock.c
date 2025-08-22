#include "pthread_impl.h"

int __pthread_rwlock_timedrdlock(pthread_rwlock_t *restrict rw, const struct timespec *restrict at)
{
	return pthread_rwlock_rdlock(rw);
}

weak_alias(__pthread_rwlock_timedrdlock, pthread_rwlock_timedrdlock);
