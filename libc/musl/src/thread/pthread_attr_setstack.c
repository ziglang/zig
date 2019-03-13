#include "pthread_impl.h"

int pthread_attr_setstack(pthread_attr_t *a, void *addr, size_t size)
{
	if (size-PTHREAD_STACK_MIN > SIZE_MAX/4) return EINVAL;
	a->_a_stackaddr = (size_t)addr + size;
	a->_a_stacksize = size;
	return 0;
}
