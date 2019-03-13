#include <fcntl.h>
#include <string.h>

int __fmodeflags(const char *mode)
{
	int flags;
	if (strchr(mode, '+')) flags = O_RDWR;
	else if (*mode == 'r') flags = O_RDONLY;
	else flags = O_WRONLY;
	if (strchr(mode, 'x')) flags |= O_EXCL;
	if (strchr(mode, 'e')) flags |= O_CLOEXEC;
	if (*mode != 'r') flags |= O_CREAT;
	if (*mode == 'w') flags |= O_TRUNC;
	if (*mode == 'a') flags |= O_APPEND;
	return flags;
}
