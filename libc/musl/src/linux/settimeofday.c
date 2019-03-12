#define _BSD_SOURCE
#include <sys/time.h>
#include "syscall.h"

int settimeofday(const struct timeval *tv, const struct timezone *tz)
{
	return syscall(SYS_settimeofday, tv, 0);
}
