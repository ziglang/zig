#include <threads.h>
#include <pthread.h>

int tss_create(tss_t *tss, tss_dtor_t dtor)
{
	/* Different error returns are possible. C glues them together into
	 * just failure notification. Can't be optimized to a tail call,
	 * unless thrd_error equals EAGAIN. */
	return __pthread_key_create(tss, dtor) ? thrd_error : thrd_success;
}
