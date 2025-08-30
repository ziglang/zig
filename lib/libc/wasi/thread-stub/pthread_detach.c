#include "pthread_impl.h"

static int __pthread_detach(pthread_t t)
{
	/*
		If we are the only thread, when we exit the whole process exits.
		So the storage will be reclaimed no matter what.
	*/
	return 0;
}

weak_alias(__pthread_detach, pthread_detach);
weak_alias(__pthread_detach, thrd_detach);
