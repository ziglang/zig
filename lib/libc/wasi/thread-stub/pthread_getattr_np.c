#include "pthread_impl.h"

int pthread_getattr_np(pthread_t t, pthread_attr_t *a)
{
	*a = (pthread_attr_t){0};
	/* Can't join main thread. */
	a->_a_detach = PTHREAD_CREATE_DETACHED;
	/* WASI doesn't have memory protection required for stack guards. */
	a->_a_guardsize = 0;
	return 0;
}
