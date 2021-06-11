#include <sys/timerfd.h>
#include <errno.h>
#include "syscall.h"

#define IS32BIT(x) !((x)+0x80000000ULL>>32)

int timerfd_create(int clockid, int flags)
{
	return syscall(SYS_timerfd_create, clockid, flags);
}

int timerfd_settime(int fd, int flags, const struct itimerspec *new, struct itimerspec *old)
{
#ifdef SYS_timerfd_settime64
	time_t is = new->it_interval.tv_sec, vs = new->it_value.tv_sec;
	long ins = new->it_interval.tv_nsec, vns = new->it_value.tv_nsec;
	int r = -ENOSYS;
	if (SYS_timerfd_settime == SYS_timerfd_settime64
	    || !IS32BIT(is) || !IS32BIT(vs) || (sizeof(time_t)>4 && old))
		r = __syscall(SYS_timerfd_settime64, fd, flags,
			((long long[]){is, ins, vs, vns}), old);
	if (SYS_timerfd_settime == SYS_timerfd_settime64 || r!=-ENOSYS)
		return __syscall_ret(r);
	if (!IS32BIT(is) || !IS32BIT(vs))
		return __syscall_ret(-ENOTSUP);
	long old32[4];
	r = __syscall(SYS_timerfd_settime, fd, flags,
		((long[]){is, ins, vs, vns}), old32);
	if (!r && old) {
		old->it_interval.tv_sec = old32[0];
		old->it_interval.tv_nsec = old32[1];
		old->it_value.tv_sec = old32[2];
		old->it_value.tv_nsec = old32[3];
	}
	return __syscall_ret(r);
#endif
	return syscall(SYS_timerfd_settime, fd, flags, new, old);
}

int timerfd_gettime(int fd, struct itimerspec *cur)
{
#ifdef SYS_timerfd_gettime64
	int r = -ENOSYS;
	if (sizeof(time_t) > 4)
		r = __syscall(SYS_timerfd_gettime64, fd, cur);
	if (SYS_timerfd_gettime == SYS_timerfd_gettime64 || r!=-ENOSYS)
		return __syscall_ret(r);
	long cur32[4];
	r = __syscall(SYS_timerfd_gettime, fd, cur32);
	if (!r) {
		cur->it_interval.tv_sec = cur32[0];
		cur->it_interval.tv_nsec = cur32[1];
		cur->it_value.tv_sec = cur32[2];
		cur->it_value.tv_nsec = cur32[3];
	}
	return __syscall_ret(r);
#endif
	return syscall(SYS_timerfd_gettime, fd, cur);
}
