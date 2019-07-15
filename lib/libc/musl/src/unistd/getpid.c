#include <unistd.h>
#include "syscall.h"

pid_t getpid(void)
{
	return __syscall(SYS_getpid);
}
