#include "pthread_impl.h"

int pthread_rwlockattr_init(pthread_rwlockattr_t *a)
{
	*a = (pthread_rwlockattr_t){0};
	return 0;
}
