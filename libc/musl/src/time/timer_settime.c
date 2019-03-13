#include <time.h>
#include <limits.h>
#include "pthread_impl.h"

int timer_settime(timer_t t, int flags, const struct itimerspec *restrict val, struct itimerspec *restrict old)
{
	if ((intptr_t)t < 0) {
		pthread_t td = (void *)((uintptr_t)t << 1);
		t = (void *)(uintptr_t)(td->timer_id & INT_MAX);
	}
	return syscall(SYS_timer_settime, t, flags, val, old);
}
