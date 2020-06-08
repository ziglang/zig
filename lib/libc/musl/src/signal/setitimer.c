#include <sys/time.h>
#include <errno.h>
#include "syscall.h"

#define IS32BIT(x) !((x)+0x80000000ULL>>32)

int setitimer(int which, const struct itimerval *restrict new, struct itimerval *restrict old)
{
	if (sizeof(time_t) > sizeof(long)) {
		time_t is = new->it_interval.tv_sec, vs = new->it_value.tv_sec;
		long ius = new->it_interval.tv_usec, vus = new->it_value.tv_usec;
		if (!IS32BIT(is) || !IS32BIT(vs))
			return __syscall_ret(-ENOTSUP);
		long old32[4];
		int r = __syscall(SYS_setitimer, which,
			((long[]){is, ius, vs, vus}), old32);
		if (!r && old) {
			old->it_interval.tv_sec = old32[0];
			old->it_interval.tv_usec = old32[1];
			old->it_value.tv_sec = old32[2];
			old->it_value.tv_usec = old32[3];
		}
		return __syscall_ret(r);
	}
	return syscall(SYS_setitimer, which, new, old);
}
