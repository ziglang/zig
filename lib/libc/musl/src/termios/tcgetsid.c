#include <termios.h>
#include <sys/ioctl.h>

pid_t tcgetsid(int fd)
{
	int sid;
	if (ioctl(fd, TIOCGSID, &sid) < 0)
		return -1;
	return sid;
}
