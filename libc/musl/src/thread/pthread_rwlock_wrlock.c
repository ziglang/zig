#include "pthread_impl.h"

int pthread_rwlock_wrlock(pthread_rwlock_t *rw)
{
	return pthread_rwlock_timedwrlock(rw, 0);
}
