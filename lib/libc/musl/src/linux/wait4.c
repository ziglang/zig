#define _GNU_SOURCE
#include <sys/wait.h>
#include <sys/resource.h>
#include <string.h>
#include <errno.h>
#include "syscall.h"

pid_t wait4(pid_t pid, int *status, int options, struct rusage *ru)
{
	int r;
#ifdef SYS_wait4_time64
	if (ru) {
		long long kru64[18];
		r = __syscall(SYS_wait4_time64, pid, status, options, kru64);
		if (r > 0) {
			ru->ru_utime = (struct timeval)
				{ .tv_sec = kru64[0], .tv_usec = kru64[1] };
			ru->ru_stime = (struct timeval)
				{ .tv_sec = kru64[2], .tv_usec = kru64[3] };
			char *slots = (char *)&ru->ru_maxrss;
			for (int i=0; i<14; i++)
				*(long *)(slots + i*sizeof(long)) = kru64[4+i];
		}
		if (SYS_wait4_time64 == SYS_wait4 || r != -ENOSYS)
			return __syscall_ret(r);
	}
#endif
	char *dest = ru ? (char *)&ru->ru_maxrss - 4*sizeof(long) : 0;
	r = __syscall(SYS_wait4, pid, status, options, dest);
	if (r>0 && ru && sizeof(time_t) > sizeof(long)) {
		long kru[4];
		memcpy(kru, dest, 4*sizeof(long));
		ru->ru_utime = (struct timeval)
			{ .tv_sec = kru[0], .tv_usec = kru[1] };
		ru->ru_stime = (struct timeval)
			{ .tv_sec = kru[2], .tv_usec = kru[3] };
	}
	return __syscall_ret(r);
}
