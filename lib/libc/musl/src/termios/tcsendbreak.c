#include <termios.h>
#include <sys/ioctl.h>

int tcsendbreak(int fd, int dur)
{
	/* nonzero duration is implementation-defined, so ignore it */
	return ioctl(fd, TCSBRK, 0);
}
