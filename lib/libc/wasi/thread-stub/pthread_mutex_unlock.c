#include "pthread_impl.h"

int __pthread_mutex_unlock(pthread_mutex_t *m)
{
	if (!m->_m_count) return EPERM;
	m->_m_count--;
	return 0;
}

weak_alias(__pthread_mutex_unlock, pthread_mutex_unlock);
