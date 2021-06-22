#include <unistd.h>
#include "syscall.h"

pid_t getpgid(pid_t pid)
{
	return syscall(SYS_getpgid, pid);
}
