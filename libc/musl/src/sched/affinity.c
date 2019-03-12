#define _GNU_SOURCE
#include <sched.h>
#include <string.h>
#include "pthread_impl.h"
#include "syscall.h"

int sched_setaffinity(pid_t tid, size_t size, const cpu_set_t *set)
{
	return syscall(SYS_sched_setaffinity, tid, size, set);
}

int pthread_setaffinity_np(pthread_t td, size_t size, const cpu_set_t *set)
{
	return -__syscall(SYS_sched_setaffinity, td->tid, size, set);
}

static int do_getaffinity(pid_t tid, size_t size, cpu_set_t *set)
{
	long ret = __syscall(SYS_sched_getaffinity, tid, size, set);
	if (ret < 0) return ret;
	if (ret < size) memset((char *)set+ret, 0, size-ret);
	return 0;
}

int sched_getaffinity(pid_t tid, size_t size, cpu_set_t *set)
{
	return __syscall_ret(do_getaffinity(tid, size, set));
}

int pthread_getaffinity_np(pthread_t td, size_t size, cpu_set_t *set)
{
	return -do_getaffinity(td->tid, size, set);
}
