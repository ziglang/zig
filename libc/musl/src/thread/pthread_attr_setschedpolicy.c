#include "pthread_impl.h"

int pthread_attr_setschedpolicy(pthread_attr_t *a, int policy)
{
	a->_a_policy = policy;
	return 0;
}
