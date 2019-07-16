#include <threads.h>
#include "syscall.h"

void thrd_yield()
{
	__syscall(SYS_sched_yield);
}
