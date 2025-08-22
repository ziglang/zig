#include "pthread_impl.h"

int pthread_attr_setguardsize(pthread_attr_t *a, size_t size)
{
#ifdef __wasilibc_unmodified_upstream
	if (size > SIZE_MAX/8) return EINVAL;
#else
	/* WASI doesn't have memory protection required for stack guards. */
	if (size > 0) return EINVAL;
#endif
	a->_a_guardsize = size;
	return 0;
}
