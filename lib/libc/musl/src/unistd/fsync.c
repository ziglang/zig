#include <unistd.h>
#include "syscall.h"

int fsync(int fd)
{
	return syscall_cp(SYS_fsync, fd);
}
