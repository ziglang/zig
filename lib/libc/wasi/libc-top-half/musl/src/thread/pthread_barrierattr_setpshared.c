#include "pthread_impl.h"

int pthread_barrierattr_setpshared(pthread_barrierattr_t *a, int pshared)
{
	if (pshared > 1U) return EINVAL;
	a->__attr = pshared ? INT_MIN : 0;
	return 0;
}
