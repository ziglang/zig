#include <unistd.h>
#include "syscall.h"

int dup(int fd)
{
	return syscall(SYS_dup, fd);
}
