#include <mqueue.h>
#include <fcntl.h>
#include <stdarg.h>
#include "syscall.h"

mqd_t mq_open(const char *name, int flags, ...)
{
	mode_t mode = 0;
	struct mq_attr *attr = 0;
	if (*name == '/') name++;
	if (flags & O_CREAT) {
		va_list ap;
		va_start(ap, flags);
		mode = va_arg(ap, mode_t);
		attr = va_arg(ap, struct mq_attr *);
		va_end(ap);
	}
	return syscall(SYS_mq_open, name, flags, mode, attr);
}
