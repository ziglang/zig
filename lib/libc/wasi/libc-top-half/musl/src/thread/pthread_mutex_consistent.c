#include "pthread_impl.h"
#include "atomic.h"

int pthread_mutex_consistent(pthread_mutex_t *m)
{
	int old = m->_m_lock;
	int own = old & 0x3fffffff;
	if (!(m->_m_type & 4) || !own || !(old & 0x40000000))
		return EINVAL;
	if (own != __pthread_self()->tid)
		return EPERM;
	a_and(&m->_m_lock, ~0x40000000);
	return 0;
}
