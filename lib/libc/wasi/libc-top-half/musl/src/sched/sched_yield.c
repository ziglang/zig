#include <sched.h>
#include "syscall.h"

int sched_yield()
{
	return syscall(SYS_sched_yield);
}
