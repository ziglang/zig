#include "pthread_impl.h"
#include <threads.h>

int thrd_create(thrd_t *thr, thrd_start_t func, void *arg)
{
	int ret = __pthread_create(thr, __ATTRP_C11_THREAD, (void *(*)(void *))func, arg);
	switch (ret) {
	case 0:      return thrd_success;
	case EAGAIN: return thrd_nomem;
	default:     return thrd_error;
	}
}
