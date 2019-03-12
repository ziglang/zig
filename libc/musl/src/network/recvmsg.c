#include <sys/socket.h>
#include <limits.h>
#include "syscall.h"

ssize_t recvmsg(int fd, struct msghdr *msg, int flags)
{
	ssize_t r;
#if LONG_MAX > INT_MAX
	struct msghdr h, *orig = msg;
	if (msg) {
		h = *msg;
		h.__pad1 = h.__pad2 = 0;
		msg = &h;
	}
#endif
	r = socketcall_cp(recvmsg, fd, msg, flags, 0, 0, 0);
#if LONG_MAX > INT_MAX
	if (orig) *orig = h;
#endif
	return r;
}
