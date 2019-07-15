#include <time.h>
#include "syscall.h"

int clock_getres(clockid_t clk, struct timespec *ts)
{
	return syscall(SYS_clock_getres, clk, ts);
}
