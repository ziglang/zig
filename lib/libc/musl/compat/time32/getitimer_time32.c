#include "time32.h"
#include <time.h>
#include <sys/time.h>

int __getitimer_time32(int which, struct itimerval32 *old32)
{
	struct itimerval old;
	int r = getitimer(which, &old);
	if (r) return r;
	old32->it_interval.tv_sec = old.it_interval.tv_sec;
	old32->it_interval.tv_usec = old.it_interval.tv_usec;
	old32->it_value.tv_sec = old.it_value.tv_sec;
	old32->it_value.tv_usec = old.it_value.tv_usec;
	return 0;
}
