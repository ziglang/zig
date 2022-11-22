#include "pthread_impl.h"

int __pthread_setcancelstate(int new, int *old)
{
#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
	if (new > 2U) return EINVAL;
	struct pthread *self = __pthread_self();
	if (old) *old = self->canceldisable;
	self->canceldisable = new;
#endif
	return 0;
}

weak_alias(__pthread_setcancelstate, pthread_setcancelstate);
