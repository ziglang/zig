#include <threads.h>
#include <pthread.h>

int cnd_signal(cnd_t *c)
{
	/* This internal function never fails, and always returns zero,
	 * which matches the value thrd_success is defined with. */
	return __private_cond_signal((pthread_cond_t *)c, 1);
}
