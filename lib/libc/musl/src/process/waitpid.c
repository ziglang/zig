#include <sys/wait.h>
#include "syscall.h"

pid_t waitpid(pid_t pid, int *status, int options)
{
	return sys_wait4_cp(pid, status, options, 0);
}
