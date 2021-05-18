#define _BSD_SOURCE
#include "time32.h"
#include <string.h>
#include <stddef.h>
#include <sys/wait.h>

struct compat_rusage {
	struct timeval32 ru_utime;
	struct timeval32 ru_stime;
	long	ru_maxrss;
	long	ru_ixrss;
	long	ru_idrss;
	long	ru_isrss;
	long	ru_minflt;
	long	ru_majflt;
	long	ru_nswap;
	long	ru_inblock;
	long	ru_oublock;
	long	ru_msgsnd;
	long	ru_msgrcv;
	long	ru_nsignals;
	long	ru_nvcsw;
	long	ru_nivcsw;
};

pid_t __wait4_time32(pid_t pid, int *status, int options, struct compat_rusage *usage)
{
	struct rusage ru;
	int r = wait4(pid, status, options, usage ? &ru : 0);
	if (!r && usage) {
		usage->ru_utime.tv_sec = ru.ru_utime.tv_sec;
		usage->ru_utime.tv_usec = ru.ru_utime.tv_usec;
		usage->ru_stime.tv_sec = ru.ru_stime.tv_sec;
		usage->ru_stime.tv_usec = ru.ru_stime.tv_usec;
		memcpy(&usage->ru_maxrss, &ru.ru_maxrss,
			sizeof(struct compat_rusage) -
			offsetof(struct compat_rusage, ru_maxrss));
	}
	return r;
}
