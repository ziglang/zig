#include <time.h>
#include <errno.h>
#include <unistd.h>
#include "syscall.h"

int clock_getcpuclockid(pid_t pid, clockid_t *clk)
{
	struct timespec ts;
	clockid_t id = (-pid-1)*8U + 2;
	int ret = __syscall(SYS_clock_getres, id, &ts);
	if (ret == -EINVAL) ret = -ESRCH;
	if (ret) return -ret;
	*clk = id;
	return 0;
}
