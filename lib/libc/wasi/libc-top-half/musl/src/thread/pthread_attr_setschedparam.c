#include "pthread_impl.h"

int pthread_attr_setschedparam(pthread_attr_t *restrict a, const struct sched_param *restrict param)
{
#ifdef __wasilibc_unmodified_upstream
	a->_a_prio = param->sched_priority;
#else
	if (param->sched_priority != 0) return ENOTSUP;
#endif
	return 0;
}
