#include "pthread_impl.h"
#include <threads.h>

static int __pthread_detach(pthread_t t)
{
	/* If the cas fails, detach state is either already-detached
	 * or exiting/exited, and pthread_join will trap or cleanup. */
	if (a_cas(&t->detach_state, DT_JOINABLE, DT_DETACHED) != DT_JOINABLE)
		return __pthread_join(t, 0);
	return 0;
}

weak_alias(__pthread_detach, pthread_detach);
weak_alias(__pthread_detach, thrd_detach);
