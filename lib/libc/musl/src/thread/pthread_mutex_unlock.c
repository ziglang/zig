#include "pthread_impl.h"

int __pthread_mutex_unlock(pthread_mutex_t *m)
{
	pthread_t self;
	int waiters = m->_m_waiters;
	int cont;
	int type = m->_m_type & 15;
	int priv = (m->_m_type & 128) ^ 128;

	if (type != PTHREAD_MUTEX_NORMAL) {
		self = __pthread_self();
		if ((m->_m_lock&0x7fffffff) != self->tid)
			return EPERM;
		if ((type&3) == PTHREAD_MUTEX_RECURSIVE && m->_m_count)
			return m->_m_count--, 0;
		if (!priv) {
			self->robust_list.pending = &m->_m_next;
			__vm_lock();
		}
		volatile void *prev = m->_m_prev;
		volatile void *next = m->_m_next;
		*(volatile void *volatile *)prev = next;
		if (next != &self->robust_list.head) *(volatile void *volatile *)
			((char *)next - sizeof(void *)) = prev;
	}
	cont = a_swap(&m->_m_lock, (type & 8) ? 0x7fffffff : 0);
	if (type != PTHREAD_MUTEX_NORMAL && !priv) {
		self->robust_list.pending = 0;
		__vm_unlock();
	}
	if (waiters || cont<0)
		__wake(&m->_m_lock, 1, priv);
	return 0;
}

weak_alias(__pthread_mutex_unlock, pthread_mutex_unlock);
