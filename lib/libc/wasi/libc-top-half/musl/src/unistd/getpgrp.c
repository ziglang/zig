#include <unistd.h>
#include "syscall.h"

pid_t getpgrp(void)
{
	return __syscall(SYS_getpgid, 0);
}
