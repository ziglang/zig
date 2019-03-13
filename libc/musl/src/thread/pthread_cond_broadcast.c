#include "pthread_impl.h"

int pthread_cond_broadcast(pthread_cond_t *c)
{
	if (!c->_c_shared) return __private_cond_signal(c, -1);
	if (!c->_c_waiters) return 0;
	a_inc(&c->_c_seq);
	__wake(&c->_c_seq, -1, 0);
	return 0;
}
