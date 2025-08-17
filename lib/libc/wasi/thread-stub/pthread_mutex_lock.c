#include "pthread_impl.h"

int __pthread_mutex_lock(pthread_mutex_t *m)
{
	/*
		_m_type[1:0] 	- type
		0 - normal
		1 - recursive
		2 - errorcheck
	*/
	if (m->_m_type&3 != PTHREAD_MUTEX_RECURSIVE) {
		if (m->_m_count) return EDEADLK;
		m->_m_count = 1;
	} else {
		if ((unsigned)m->_m_count >= INT_MAX) return EAGAIN;
		m->_m_count++;
	}
	return 0;
}

weak_alias(__pthread_mutex_lock, pthread_mutex_lock);
