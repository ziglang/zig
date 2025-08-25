#include "time32.h"
#include <time.h>
#include <sys/timerfd.h>

int __timerfd_settime32(int t, int flags, const struct itimerspec32 *restrict val32, struct itimerspec32 *restrict old32)
{
	struct itimerspec old;
	int r = timerfd_settime(t, flags, (&(struct itimerspec){
		.it_interval.tv_sec = val32->it_interval.tv_sec,
		.it_interval.tv_nsec = val32->it_interval.tv_nsec,
		.it_value.tv_sec = val32->it_value.tv_sec,
		.it_value.tv_nsec = val32->it_value.tv_nsec}),
		old32 ? &old : 0);
	if (r) return r;
	/* The above call has already committed to success by changing the
	 * timer setting, so we can't fail on out-of-range old value.
	 * Since these are relative times, values large enough to overflow
	 * don't make sense anyway. */
	if (old32) {
		old32->it_interval.tv_sec = old.it_interval.tv_sec;
		old32->it_interval.tv_nsec = old.it_interval.tv_nsec;
		old32->it_value.tv_sec = old.it_value.tv_sec;
		old32->it_value.tv_nsec = old.it_value.tv_nsec;
	}
	return 0;
}
