#include "pthread_impl.h"

int pthread_rwlock_tryrdlock(pthread_rwlock_t *rw)
{
	int val, cnt;
	do {
		val = rw->_rw_lock;
		cnt = val & 0x7fffffff;
		if (cnt == 0x7fffffff) return EBUSY;
		if (cnt == 0x7ffffffe) return EAGAIN;
	} while (a_cas(&rw->_rw_lock, val, val+1) != val);
	return 0;
}
