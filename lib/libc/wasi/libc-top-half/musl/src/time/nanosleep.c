#include <time.h>
#include "syscall.h"

int nanosleep(const struct timespec *req, struct timespec *rem)
{
	return __syscall_ret(-__clock_nanosleep(CLOCK_REALTIME, 0, req, rem));
}
