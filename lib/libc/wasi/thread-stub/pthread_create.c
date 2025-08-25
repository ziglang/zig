#include "pthread_impl.h"

static void dummy_0()
{
}
weak_alias(dummy_0, __acquire_ptc);
weak_alias(dummy_0, __release_ptc);

int __pthread_create(pthread_t *restrict res, const pthread_attr_t *restrict attrp, void *(*entry)(void *), void *restrict arg)
{
	/*
		"The system lacked the necessary resources to create another thread,
		or the system-imposed limit on the total number of threads in a process
		{PTHREAD_THREADS_MAX} would be exceeded."
	*/
	return EAGAIN;
}

weak_alias(__pthread_create, pthread_create);
