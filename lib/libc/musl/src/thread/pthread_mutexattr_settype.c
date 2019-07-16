#include "pthread_impl.h"

int pthread_mutexattr_settype(pthread_mutexattr_t *a, int type)
{
	if ((unsigned)type > 2) return EINVAL;
	a->__attr = (a->__attr & ~3) | type;
	return 0;
}
