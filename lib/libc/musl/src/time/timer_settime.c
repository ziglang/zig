#include <time.h>
#include <limits.h>
#include "pthread_impl.h"

#define IS32BIT(x) !((x)+0x80000000ULL>>32)

int timer_settime(timer_t t, int flags, const struct itimerspec *restrict val, struct itimerspec *restrict old)
{
	if ((intptr_t)t < 0) {
		pthread_t td = (void *)((uintptr_t)t << 1);
		t = (void *)(uintptr_t)(td->timer_id & INT_MAX);
	}
#ifdef SYS_timer_settime64
	time_t is = val->it_interval.tv_sec, vs = val->it_value.tv_sec;
	long ins = val->it_interval.tv_nsec, vns = val->it_value.tv_nsec;
	int r = -ENOSYS;
	if (SYS_timer_settime == SYS_timer_settime64
	    || !IS32BIT(is) || !IS32BIT(vs) || (sizeof(time_t)>4 && old))
		r = __syscall(SYS_timer_settime64, t, flags,
			((long long[]){is, ins, vs, vns}), old);
	if (SYS_timer_settime == SYS_timer_settime64 || r!=-ENOSYS)
		return __syscall_ret(r);
	if (!IS32BIT(is) || !IS32BIT(vs))
		return __syscall_ret(-ENOTSUP);
	long old32[4];
	r = __syscall(SYS_timer_settime, t, flags,
		((long[]){is, ins, vs, vns}), old32);
	if (!r && old) {
		old->it_interval.tv_sec = old32[0];
		old->it_interval.tv_nsec = old32[1];
		old->it_value.tv_sec = old32[2];
		old->it_value.tv_nsec = old32[3];
	}
	return __syscall_ret(r);
#endif
	return syscall(SYS_timer_settime, t, flags, val, old);
}
