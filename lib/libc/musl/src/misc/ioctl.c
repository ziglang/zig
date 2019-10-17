#include <sys/ioctl.h>
#include <stdarg.h>
#include <errno.h>
#include <time.h>
#include <sys/time.h>
#include "syscall.h"

int ioctl(int fd, int req, ...)
{
	void *arg;
	va_list ap;
	va_start(ap, req);
	arg = va_arg(ap, void *);
	va_end(ap);
	int r = __syscall(SYS_ioctl, fd, req, arg);
	if (r==-ENOTTY) switch (req) {
	case SIOCGSTAMP:
	case SIOCGSTAMPNS:
		if (SIOCGSTAMP==SIOCGSTAMP_OLD) break;
		if (req==SIOCGSTAMP) req=SIOCGSTAMP_OLD;
		if (req==SIOCGSTAMPNS) req=SIOCGSTAMPNS_OLD;
		long t32[2];
		r = __syscall(SYS_ioctl, fd, req, t32);
		if (r<0) break;
		if (req==SIOCGSTAMP_OLD) {
			struct timeval *tv = arg;
			tv->tv_sec = t32[0];
			tv->tv_usec = t32[1];
		} else {
			struct timespec *ts = arg;
			ts->tv_sec = t32[0];
			ts->tv_nsec = t32[1];
		}
	}
	return __syscall_ret(r);
}
