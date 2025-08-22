#include "pthread_impl.h"

int __pthread_rwlock_wrlock(pthread_rwlock_t *rw)
{
	if (rw->_rw_lock) return EDEADLK;
	rw->_rw_lock = 0x7fffffff;
	return 0;
}

weak_alias(__pthread_rwlock_wrlock, pthread_rwlock_wrlock);
