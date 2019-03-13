#include <termios.h>
#include <sys/ioctl.h>

int tcgetattr(int fd, struct termios *tio)
{
	if (ioctl(fd, TCGETS, tio))
		return -1;
	return 0;
}
