#include "pthread_impl.h"

int pthread_spin_unlock(pthread_spinlock_t *s)
{
	*s = 0;
	return 0;
}
