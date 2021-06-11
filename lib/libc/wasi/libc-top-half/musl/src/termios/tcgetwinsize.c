#include <termios.h>
#include <sys/ioctl.h>
#include "syscall.h"

int tcgetwinsize(int fd, struct winsize *wsz)
{
	return syscall(SYS_ioctl, fd, TIOCGWINSZ, wsz);
}
