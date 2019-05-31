#include "pthread_impl.h"
#include "syscall.h"

static pthread_once_t check_pi_once;
static int check_pi_result;

static void check_pi()
{
	volatile int lk = 0;
	check_pi_result = -__syscall(SYS_futex, &lk, FUTEX_LOCK_PI, 0, 0);
}

int pthread_mutexattr_setprotocol(pthread_mutexattr_t *a, int protocol)
{
	switch (protocol) {
	case PTHREAD_PRIO_NONE:
		a->__attr &= ~8;
		return 0;
	case PTHREAD_PRIO_INHERIT:
		pthread_once(&check_pi_once, check_pi);
		if (check_pi_result) return check_pi_result;
		a->__attr |= 8;
		return 0;
	case PTHREAD_PRIO_PROTECT:
		return ENOTSUP;
	default:
		return EINVAL;
	}
}
