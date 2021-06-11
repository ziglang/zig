#include "pthread_impl.h"

int __pthread_rwlock_timedrdlock(pthread_rwlock_t *restrict rw, const struct timespec *restrict at)
{
	int r, t;

	r = pthread_rwlock_tryrdlock(rw);
	if (r != EBUSY) return r;
	
	int spins = 100;
	while (spins-- && rw->_rw_lock && !rw->_rw_waiters) a_spin();

	while ((r=__pthread_rwlock_tryrdlock(rw))==EBUSY) {
		if (!(r=rw->_rw_lock) || (r&0x7fffffff)!=0x7fffffff) continue;
		t = r | 0x80000000;
		a_inc(&rw->_rw_waiters);
		a_cas(&rw->_rw_lock, r, t);
		r = __timedwait(&rw->_rw_lock, t, CLOCK_REALTIME, at, rw->_rw_shared^128);
		a_dec(&rw->_rw_waiters);
		if (r && r != EINTR) return r;
	}
	return r;
}

weak_alias(__pthread_rwlock_timedrdlock, pthread_rwlock_timedrdlock);
