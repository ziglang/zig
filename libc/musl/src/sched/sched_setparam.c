#include <sched.h>
#include <errno.h>
#include "syscall.h"

int sched_setparam(pid_t pid, const struct sched_param *param)
{
	return __syscall_ret(-ENOSYS);
}
