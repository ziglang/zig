#include <sys/resource.h>
#include <string.h>
#include <errno.h>
#include "syscall.h"

int getrusage(int who, struct rusage *ru)
{
	int r;
#ifdef SYS_getrusage_time64
	long long kru64[18];
	r = __syscall(SYS_getrusage_time64, who, kru64);
	if (!r) {
		ru->ru_utime = (struct timeval)
			{ .tv_sec = kru64[0], .tv_usec = kru64[1] };
		ru->ru_stime = (struct timeval)
			{ .tv_sec = kru64[2], .tv_usec = kru64[3] };
		char *slots = (char *)&ru->ru_maxrss;
		for (int i=0; i<14; i++)
			*(long *)(slots + i*sizeof(long)) = kru64[4+i];
	}
	if (SYS_getrusage_time64 == SYS_getrusage || r != -ENOSYS)
		return __syscall_ret(r);
#endif
	char *dest = (char *)&ru->ru_maxrss - 4*sizeof(long);
	r = __syscall(SYS_getrusage, who, dest);
	if (!r && sizeof(time_t) > sizeof(long)) {
		long kru[4];
		memcpy(kru, dest, 4*sizeof(long));
		ru->ru_utime = (struct timeval)
			{ .tv_sec = kru[0], .tv_usec = kru[1] };
		ru->ru_stime = (struct timeval)
			{ .tv_sec = kru[2], .tv_usec = kru[3] };
	}
	return __syscall_ret(r);
}
