#include "pthread_impl.h"

int pthread_spin_trylock(pthread_spinlock_t *s)
{
	if (*s) return EBUSY;
	*s = 1;
	return 0;
}
