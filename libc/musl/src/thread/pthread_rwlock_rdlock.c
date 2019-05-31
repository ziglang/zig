#include "pthread_impl.h"

int __pthread_rwlock_rdlock(pthread_rwlock_t *rw)
{
	return __pthread_rwlock_timedrdlock(rw, 0);
}

weak_alias(__pthread_rwlock_rdlock, pthread_rwlock_rdlock);
