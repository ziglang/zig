#include <time.h>
#include "syscall.h"

int nanosleep(const struct timespec *req, struct timespec *rem)
{
	return syscall_cp(SYS_nanosleep, req, rem);
}
