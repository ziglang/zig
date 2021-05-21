#include "pthread_impl.h"

int pthread_cond_wait(pthread_cond_t *restrict c, pthread_mutex_t *restrict m)
{
	return pthread_cond_timedwait(c, m, 0);
}
