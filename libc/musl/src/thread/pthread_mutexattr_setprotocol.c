#include "pthread_impl.h"

int pthread_mutexattr_setprotocol(pthread_mutexattr_t *a, int protocol)
{
	if (protocol) return ENOTSUP;
	return 0;
}
