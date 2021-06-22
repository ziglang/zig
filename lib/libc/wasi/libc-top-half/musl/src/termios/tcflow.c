#include <termios.h>
#include <sys/ioctl.h>

int tcflow(int fd, int action)
{
	return ioctl(fd, TCXONC, action);
}
