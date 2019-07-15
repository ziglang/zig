#include <unistd.h>
#include "syscall.h"

pid_t getppid(void)
{
	return __syscall(SYS_getppid);
}
