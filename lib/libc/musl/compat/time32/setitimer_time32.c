#include "time32.h"
#include <time.h>
#include <sys/time.h>

int __setitimer_time32(int which, const struct itimerval32 *restrict new32, struct itimerval32 *restrict old32)
{
	struct itimerval old;
	int r = setitimer(which, (&(struct itimerval){
		.it_interval.tv_sec = new32->it_interval.tv_sec,
		.it_interval.tv_usec = new32->it_interval.tv_usec,
		.it_value.tv_sec = new32->it_value.tv_sec,
		.it_value.tv_usec = new32->it_value.tv_usec}), &old);
	if (r) return r;
	/* The above call has already committed to success by changing the
	 * timer setting, so we can't fail on out-of-range old value.
	 * Since these are relative times, values large enough to overflow
	 * don't make sense anyway. */
	if (old32) {
		old32->it_interval.tv_sec = old.it_interval.tv_sec;
		old32->it_interval.tv_usec = old.it_interval.tv_usec;
		old32->it_value.tv_sec = old.it_value.tv_sec;
		old32->it_value.tv_usec = old.it_value.tv_usec;
	}
	return 0;
}
