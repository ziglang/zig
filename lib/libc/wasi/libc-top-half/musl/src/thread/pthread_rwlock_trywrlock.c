#include "pthread_impl.h"

int __pthread_rwlock_trywrlock(pthread_rwlock_t *rw)
{
	if (a_cas(&rw->_rw_lock, 0, 0x7fffffff)) return EBUSY;
	return 0;
}

weak_alias(__pthread_rwlock_trywrlock, pthread_rwlock_trywrlock);
