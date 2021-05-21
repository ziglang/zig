#include <time.h>
#include <errno.h>
#include "syscall.h"

#define IS32BIT(x) !((x)+0x80000000ULL>>32)

int clock_settime(clockid_t clk, const struct timespec *ts)
{
#ifdef SYS_clock_settime64
	time_t s = ts->tv_sec;
	long ns = ts->tv_nsec;
	int r = -ENOSYS;
	if (SYS_clock_settime == SYS_clock_settime64 || !IS32BIT(s))
		r = __syscall(SYS_clock_settime64, clk,
			((long long[]){s, ns}));
	if (SYS_clock_settime == SYS_clock_settime64 || r!=-ENOSYS)
		return __syscall_ret(r);
	if (!IS32BIT(s))
		return __syscall_ret(-ENOTSUP);
	return syscall(SYS_clock_settime, clk, ((long[]){s, ns}));
#else
	return syscall(SYS_clock_settime, clk, ts);
#endif
}
