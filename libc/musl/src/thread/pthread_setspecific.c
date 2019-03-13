#include "pthread_impl.h"

int pthread_setspecific(pthread_key_t k, const void *x)
{
	struct pthread *self = __pthread_self();
	/* Avoid unnecessary COW */
	if (self->tsd[k] != x) {
		self->tsd[k] = (void *)x;
		self->tsd_used = 1;
	}
	return 0;
}
