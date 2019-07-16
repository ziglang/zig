#include <time.h>
#include <errno.h>
#include "syscall.h"

int clock_nanosleep(clockid_t clk, int flags, const struct timespec *req, struct timespec *rem)
{
	int r = -__syscall_cp(SYS_clock_nanosleep, clk, flags, req, rem);
	return clk == CLOCK_THREAD_CPUTIME_ID ? EINVAL : r;
}
