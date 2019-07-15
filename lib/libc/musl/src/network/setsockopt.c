#include <sys/socket.h>
#include "syscall.h"

int setsockopt(int fd, int level, int optname, const void *optval, socklen_t optlen)
{
	return socketcall(setsockopt, fd, level, optname, optval, optlen, 0);
}
