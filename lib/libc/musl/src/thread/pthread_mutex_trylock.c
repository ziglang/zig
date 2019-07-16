#include "pthread_impl.h"

int __pthread_mutex_trylock_owner(pthread_mutex_t *m)
{
	int old, own;
	int type = m->_m_type & 15;
	pthread_t self = __pthread_self();
	int tid = self->tid;

	old = m->_m_lock;
	own = old & 0x7fffffff;
	if (own == tid && (type&3) == PTHREAD_MUTEX_RECURSIVE) {
		if ((unsigned)m->_m_count >= INT_MAX) return EAGAIN;
		m->_m_count++;
		return 0;
	}
	if (own == 0x7fffffff) return ENOTRECOVERABLE;
	if (own && (!(own & 0x40000000) || !(type & 4))) return EBUSY;

	if (m->_m_type & 128) {
		if (!self->robust_list.off) {
			self->robust_list.off = (char*)&m->_m_lock-(char *)&m->_m_next;
			__syscall(SYS_set_robust_list, &self->robust_list, 3*sizeof(long));
		}
		if (m->_m_waiters) tid |= 0x80000000;
		self->robust_list.pending = &m->_m_next;
	}

	if (a_cas(&m->_m_lock, old, tid) != old) {
		self->robust_list.pending = 0;
		return EBUSY;
	}

	volatile void *next = self->robust_list.head;
	m->_m_next = next;
	m->_m_prev = &self->robust_list.head;
	if (next != &self->robust_list.head) *(volatile void *volatile *)
		((char *)next - sizeof(void *)) = &m->_m_next;
	self->robust_list.head = &m->_m_next;
	self->robust_list.pending = 0;

	if (own) {
		m->_m_count = 0;
		m->_m_type |= 8;
		return EOWNERDEAD;
	}

	return 0;
}

int __pthread_mutex_trylock(pthread_mutex_t *m)
{
	if ((m->_m_type&15) == PTHREAD_MUTEX_NORMAL)
		return a_cas(&m->_m_lock, 0, EBUSY) & EBUSY;
	return __pthread_mutex_trylock_owner(m);
}

weak_alias(__pthread_mutex_trylock, pthread_mutex_trylock);
