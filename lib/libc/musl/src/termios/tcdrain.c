#include <termios.h>
#include <sys/ioctl.h>
#include "syscall.h"

int tcdrain(int fd)
{
	return syscall_cp(SYS_ioctl, fd, TCSBRK, 1);
}
