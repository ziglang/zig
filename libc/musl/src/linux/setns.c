#define _GNU_SOURCE
#include <sched.h>
#include "syscall.h"

int setns(int fd, int nstype)
{
	return syscall(SYS_setns, fd, nstype);
}
