#include "pthread_impl.h"

int pthread_attr_setstacksize(pthread_attr_t *a, size_t size)
{
	if (size-PTHREAD_STACK_MIN > SIZE_MAX/4) return EINVAL;
	a->_a_stackaddr = 0;
	a->_a_stacksize = size;
	return 0;
}
