#include <unistd.h>
#include "syscall.h"

int pipe(int fd[2])
{
#ifdef SYS_pipe
	return syscall(SYS_pipe, fd);
#else
	return syscall(SYS_pipe2, fd, 0);
#endif
}
