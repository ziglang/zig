#include <time.h>
#include <errno.h>
#include "syscall.h"

#define IS32BIT(x) !((x)+0x80000000ULL>>32)
#define CLAMP(x) (int)(IS32BIT(x) ? (x) : 0x7fffffffU+((0ULL+(x))>>63))

int __clock_nanosleep(clockid_t clk, int flags, const struct timespec *req, struct timespec *rem)
{
	if (clk == CLOCK_THREAD_CPUTIME_ID) return EINVAL;
#ifdef SYS_clock_nanosleep_time64
	time_t s = req->tv_sec;
	long ns = req->tv_nsec;
	int r = -ENOSYS;
	if (SYS_clock_nanosleep == SYS_clock_nanosleep_time64 || !IS32BIT(s))
		r = __syscall_cp(SYS_clock_nanosleep_time64, clk, flags,
			((long long[]){s, ns}), rem);
	if (SYS_clock_nanosleep == SYS_clock_nanosleep_time64 || r!=-ENOSYS)
		return -r;
	long long extra = s - CLAMP(s);
	long ts32[2] = { CLAMP(s), ns };
	if (clk == CLOCK_REALTIME && !flags)
		r = __syscall_cp(SYS_nanosleep, &ts32, &ts32);
	else
		r = __syscall_cp(SYS_clock_nanosleep, clk, flags, &ts32, &ts32);
	if (r==-EINTR && rem && !(flags & TIMER_ABSTIME)) {
		rem->tv_sec = ts32[0] + extra;
		rem->tv_nsec = ts32[1];
	}
	return -r;
#else
	if (clk == CLOCK_REALTIME && !flags)
		return -__syscall_cp(SYS_nanosleep, req, rem);
	return -__syscall_cp(SYS_clock_nanosleep, clk, flags, req, rem);
#endif
}

weak_alias(__clock_nanosleep, clock_nanosleep);
