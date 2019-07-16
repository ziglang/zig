#include <pthread.h>
#include <time.h>
#include <errno.h>
#include "futex.h"
#include "syscall.h"
#include "pthread_impl.h"

static volatile int dummy = 0;
weak_alias(dummy, __eintr_valid_flag);

int __timedwait_cp(volatile int *addr, int val,
	clockid_t clk, const struct timespec *at, int priv)
{
	int r;
	struct timespec to, *top=0;

	if (priv) priv = FUTEX_PRIVATE;

	if (at) {
		if (at->tv_nsec >= 1000000000UL) return EINVAL;
		if (__clock_gettime(clk, &to)) return EINVAL;
		to.tv_sec = at->tv_sec - to.tv_sec;
		if ((to.tv_nsec = at->tv_nsec - to.tv_nsec) < 0) {
			to.tv_sec--;
			to.tv_nsec += 1000000000;
		}
		if (to.tv_sec < 0) return ETIMEDOUT;
		top = &to;
	}

	r = -__syscall_cp(SYS_futex, addr, FUTEX_WAIT|priv, val, top);
	if (r == ENOSYS) r = -__syscall_cp(SYS_futex, addr, FUTEX_WAIT, val, top);
	if (r != EINTR && r != ETIMEDOUT && r != ECANCELED) r = 0;
	/* Mitigate bug in old kernels wrongly reporting EINTR for non-
	 * interrupting (SA_RESTART) signal handlers. This is only practical
	 * when NO interrupting signal handlers have been installed, and
	 * works by sigaction tracking whether that's the case. */
	if (r == EINTR && !__eintr_valid_flag) r = 0;

	return r;
}

int __timedwait(volatile int *addr, int val,
	clockid_t clk, const struct timespec *at, int priv)
{
	int cs, r;
	__pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cs);
	r = __timedwait_cp(addr, val, clk, at, priv);
	__pthread_setcancelstate(cs, 0);
	return r;
}
