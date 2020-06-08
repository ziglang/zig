#include <sched.h>
#include "syscall.h"

int sched_rr_get_interval(pid_t pid, struct timespec *ts)
{
#ifdef SYS_sched_rr_get_interval_time64
	/* On a 32-bit arch, use the old syscall if it exists. */
	if (SYS_sched_rr_get_interval != SYS_sched_rr_get_interval_time64) {
		long ts32[2];
		int r = __syscall(SYS_sched_rr_get_interval, pid, ts32);
		if (!r) {
			ts->tv_sec = ts32[0];
			ts->tv_nsec = ts32[1];
		}
		return __syscall_ret(r);
	}
#endif
	/* If reaching this point, it's a 64-bit arch or time64-only
	 * 32-bit arch and we can get result directly into timespec. */
	return syscall(SYS_sched_rr_get_interval, pid, ts);
}
