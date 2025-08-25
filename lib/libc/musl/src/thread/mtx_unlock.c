#include <threads.h>
#include <pthread.h>

int mtx_unlock(mtx_t *mtx)
{
	/* The only cases where pthread_mutex_unlock can return an
	 * error are undefined behavior for C11 mtx_unlock, so we can
	 * assume it does not return an error and simply tail call. */
	return __pthread_mutex_unlock((pthread_mutex_t *)mtx);
}
