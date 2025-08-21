#include "pthread_impl.h"

#ifndef __wasilibc_unmodified_upstream
#include <common/clock.h>
#endif

int pthread_attr_getdetachstate(const pthread_attr_t *a, int *state)
{
	*state = a->_a_detach;
	return 0;
}
int pthread_attr_getguardsize(const pthread_attr_t *restrict a, size_t *restrict size)
{
	*size = a->_a_guardsize;
	return 0;
}

#ifdef __wasilibc_unmodified_upstream /* WASI has no CPU scheduling support. */
int pthread_attr_getinheritsched(const pthread_attr_t *restrict a, int *restrict inherit)
{
	*inherit = a->_a_sched;
	return 0;
}

int pthread_attr_getschedparam(const pthread_attr_t *restrict a, struct sched_param *restrict param)
{
	param->sched_priority = a->_a_prio;
	return 0;
}

int pthread_attr_getschedpolicy(const pthread_attr_t *restrict a, int *restrict policy)
{
	*policy = a->_a_policy;
	return 0;
}

int pthread_attr_getscope(const pthread_attr_t *restrict a, int *restrict scope)
{
	*scope = PTHREAD_SCOPE_SYSTEM;
	return 0;
}
#else
int pthread_attr_getschedparam(const pthread_attr_t *restrict a, struct sched_param *restrict param)
{
	param->sched_priority = 0;
	return 0;
}
#endif

int pthread_attr_getstack(const pthread_attr_t *restrict a, void **restrict addr, size_t *restrict size)
{
	if (!a->_a_stackaddr)
		return EINVAL;
	*size = a->_a_stacksize;
	*addr = (void *)(a->_a_stackaddr - *size);
	return 0;
}

int pthread_attr_getstacksize(const pthread_attr_t *restrict a, size_t *restrict size)
{
	*size = a->_a_stacksize;
	return 0;
}

int pthread_barrierattr_getpshared(const pthread_barrierattr_t *restrict a, int *restrict pshared)
{
	*pshared = !!a->__attr;
	return 0;
}

#ifdef __wasilibc_unmodified_upstream /* Forward declaration of WASI's `__clockid` type. */
int pthread_condattr_getclock(const pthread_condattr_t *restrict a, clockid_t *restrict clk)
{
	*clk = a->__attr & 0x7fffffff;
	return 0;
}
#else
int pthread_condattr_getclock(const pthread_condattr_t *restrict a, clockid_t *restrict clk)
{
	if (a->__attr & 0x7fffffff == __WASI_CLOCKID_REALTIME)
		*clk = CLOCK_REALTIME;
	if (a->__attr & 0x7fffffff == __WASI_CLOCKID_MONOTONIC)
		*clk = CLOCK_MONOTONIC;
	return 0;
}
#endif

int pthread_condattr_getpshared(const pthread_condattr_t *restrict a, int *restrict pshared)
{
	*pshared = a->__attr>>31;
	return 0;
}

int pthread_mutexattr_getprotocol(const pthread_mutexattr_t *restrict a, int *restrict protocol)
{
	*protocol = a->__attr / 8U % 2;
	return 0;
}
int pthread_mutexattr_getpshared(const pthread_mutexattr_t *restrict a, int *restrict pshared)
{
	*pshared = a->__attr / 128U % 2;
	return 0;
}

int pthread_mutexattr_getrobust(const pthread_mutexattr_t *restrict a, int *restrict robust)
{
	*robust = a->__attr / 4U % 2;
	return 0;
}

int pthread_mutexattr_gettype(const pthread_mutexattr_t *restrict a, int *restrict type)
{
	*type = a->__attr & 3;
	return 0;
}

int pthread_rwlockattr_getpshared(const pthread_rwlockattr_t *restrict a, int *restrict pshared)
{
	*pshared = a->__attr[0];
	return 0;
}
