#include <unistd.h>
#include "syscall.h"

int fdatasync(int fd)
{
	return syscall_cp(SYS_fdatasync, fd);
}
