#include <threads.h>
#include <pthread.h>
#include <errno.h>

int cnd_timedwait(cnd_t *restrict c, mtx_t *restrict m, const struct timespec *restrict ts)
{
	int ret = __pthread_cond_timedwait((pthread_cond_t *)c, (pthread_mutex_t *)m, ts);
	switch (ret) {
	/* May also return EINVAL or EPERM. */
	default:        return thrd_error;
	case 0:         return thrd_success;
	case ETIMEDOUT: return thrd_timedout;
	}
}
