#define _GNU_SOURCE
#include <unistd.h>
#include <limits.h>
#include <sys/resource.h>

int getdtablesize(void)
{
	struct rlimit rl;
	getrlimit(RLIMIT_NOFILE, &rl);
	return rl.rlim_cur < INT_MAX ? rl.rlim_cur : INT_MAX;
}
