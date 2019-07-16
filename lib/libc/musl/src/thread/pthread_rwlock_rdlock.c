#include "pthread_impl.h"

int pthread_rwlock_rdlock(pthread_rwlock_t *rw)
{
	return pthread_rwlock_timedrdlock(rw, 0);
}
