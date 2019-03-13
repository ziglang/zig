#include <mqueue.h>
#include <errno.h>
#include "syscall.h"

int mq_unlink(const char *name)
{
	int ret;
	if (*name == '/') name++;
	ret = __syscall(SYS_mq_unlink, name);
	if (ret < 0) {
		if (ret == -EPERM) ret = -EACCES;
		errno = -ret;
		return -1;
	}
	return ret;
}
