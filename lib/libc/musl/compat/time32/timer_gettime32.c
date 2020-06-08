#include "time32.h"
#include <time.h>

int __timer_gettime32(timer_t t, struct itimerspec32 *val32)
{
	struct itimerspec old;
	int r = timer_gettime(t, &old);
	if (r) return r;
	/* No range checking for consistency with settime */
	val32->it_interval.tv_sec = old.it_interval.tv_sec;
	val32->it_interval.tv_nsec = old.it_interval.tv_nsec;
	val32->it_value.tv_sec = old.it_value.tv_sec;
	val32->it_value.tv_nsec = old.it_value.tv_nsec;
	return 0;
}
