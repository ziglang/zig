#include <unistd.h>
#include "syscall.h"

int setpgid(pid_t pid, pid_t pgid)
{
	return syscall(SYS_setpgid, pid, pgid);
}
