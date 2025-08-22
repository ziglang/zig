#include "pthread_impl.h"

int __pthread_cond_timedwait(pthread_cond_t *restrict c, pthread_mutex_t *restrict m, const struct timespec *restrict ts)
{
	/* Error check mutexes must detect if they're not locked (UB for others) */
	if (!m->_m_count) return EPERM;
	int ret = clock_nanosleep(CLOCK_REALTIME, TIMER_ABSTIME, ts, 0);
	if (ret == 0) return ETIMEDOUT;
	if (ret != EINTR) return ret;
	return 0;
}

weak_alias(__pthread_cond_timedwait, pthread_cond_timedwait);
