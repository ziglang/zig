#include "pthread_impl.h"

static int __pthread_tryjoin_np(pthread_t t, void **res)
{
	/*
		"The behavior is undefined if the value specified by the thread argument
		to pthread_join() refers to the calling thread."
	*/
	return 0;
}

static int __pthread_timedjoin_np(pthread_t t, void **res, const struct timespec *at)
{
	/*
		"The behavior is undefined if the value specified by the thread argument
		to pthread_join() refers to the calling thread."
	*/
	return 0;
}

int __pthread_join(pthread_t t, void **res)
{
	/*
		"The behavior is undefined if the value specified by the thread argument
		to pthread_join() refers to the calling thread."
	*/
	return 0;
}

weak_alias(__pthread_tryjoin_np, pthread_tryjoin_np);
weak_alias(__pthread_timedjoin_np, pthread_timedjoin_np);
weak_alias(__pthread_join, pthread_join);
