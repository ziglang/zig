#include <sys/stat.h>
#include <sys/time.h>
#include <fcntl.h>
#include <errno.h>
#include "syscall.h"

#define IS32BIT(x) !((x)+0x80000000ULL>>32)
#define NS_SPECIAL(ns) ((ns)==UTIME_NOW || (ns)==UTIME_OMIT)

int utimensat(int fd, const char *path, const struct timespec times[2], int flags)
{
	int r;
	if (times && times[0].tv_nsec==UTIME_NOW && times[1].tv_nsec==UTIME_NOW)
		times = 0;
#ifdef SYS_utimensat_time64
	r = -ENOSYS;
	time_t s0=0, s1=0;
	long ns0=0, ns1=0;
	if (times) {
		ns0 = times[0].tv_nsec;
		ns1 = times[1].tv_nsec;
		if (!NS_SPECIAL(ns0)) s0 = times[0].tv_sec;
		if (!NS_SPECIAL(ns1)) s1 = times[1].tv_sec;
	}
	if (SYS_utimensat == SYS_utimensat_time64 || !IS32BIT(s0) || !IS32BIT(s1))
		r = __syscall(SYS_utimensat_time64, fd, path, times ?
			((long long[]){s0, ns0, s1, ns1}) : 0, flags);
	if (SYS_utimensat == SYS_utimensat_time64 || r!=-ENOSYS)
		return __syscall_ret(r);
	if (!IS32BIT(s0) || !IS32BIT(s1))
		return __syscall_ret(-ENOTSUP);
	r = __syscall(SYS_utimensat, fd, path,
		times ? ((long[]){s0, ns0, s1, ns1}) : 0, flags);
#else
	r = __syscall(SYS_utimensat, fd, path, times, flags);
#endif

#ifdef SYS_futimesat
	if (r != -ENOSYS || flags) return __syscall_ret(r);
	long *tv=0, tmp[4];
	if (times) {
		int i;
		tv = tmp;
		for (i=0; i<2; i++) {
			if (times[i].tv_nsec >= 1000000000ULL) {
				if (NS_SPECIAL(times[i].tv_nsec))
					return __syscall_ret(-ENOSYS);
				return __syscall_ret(-EINVAL);
			}
			tmp[2*i+0] = times[i].tv_sec;
			tmp[2*i+1] = times[i].tv_nsec / 1000;
		}
	}

	r = __syscall(SYS_futimesat, fd, path, tv);
	if (r != -ENOSYS || fd != AT_FDCWD) return __syscall_ret(r);
	r = __syscall(SYS_utimes, path, tv);
#endif
	return __syscall_ret(r);
}
