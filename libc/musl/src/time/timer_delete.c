#include <time.h>
#include <limits.h>
#include "pthread_impl.h"

int timer_delete(timer_t t)
{
	if ((intptr_t)t < 0) {
		pthread_t td = (void *)((uintptr_t)t << 1);
		a_store(&td->timer_id, td->timer_id | INT_MIN);
		__wake(&td->timer_id, 1, 1);
		return 0;
	}
	return __syscall(SYS_timer_delete, t);
}
