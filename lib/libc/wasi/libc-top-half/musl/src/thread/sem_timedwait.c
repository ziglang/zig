#include <semaphore.h>
#include "pthread_impl.h"

static void cleanup(void *p)
{
	a_dec(p);
}

int sem_timedwait(sem_t *restrict sem, const struct timespec *restrict at)
{
	pthread_testcancel();

	if (!sem_trywait(sem)) return 0;

	int spins = 100;
	while (spins-- && sem->__val[0] <= 0 && !sem->__val[1]) a_spin();

	while (sem_trywait(sem)) {
		int r;
		a_inc(sem->__val+1);
		a_cas(sem->__val, 0, -1);
		pthread_cleanup_push(cleanup, (void *)(sem->__val+1));
		r = __timedwait_cp(sem->__val, -1, CLOCK_REALTIME, at, sem->__val[2]);
		pthread_cleanup_pop(1);
		if (r) {
			errno = r;
			return -1;
		}
	}
	return 0;
}
