#include <sys/timex.h>
#include "syscall.h"

int clock_adjtime (clockid_t clock_id, struct timex *utx)
{
	return syscall(SYS_clock_adjtime, clock_id, utx);
}
