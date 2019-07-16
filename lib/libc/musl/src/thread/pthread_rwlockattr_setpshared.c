#include "pthread_impl.h"

int pthread_rwlockattr_setpshared(pthread_rwlockattr_t *a, int pshared)
{
	if (pshared > 1U) return EINVAL;
	a->__attr[0] = pshared;
	return 0;
}
