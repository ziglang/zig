#include <time.h>
#include <setjmp.h>
#include "pthread_impl.h"

struct ksigevent {
	union sigval sigev_value;
	int sigev_signo;
	int sigev_notify;
	int sigev_tid;
};

struct start_args {
	pthread_barrier_t b;
	struct sigevent *sev;
};

static void dummy_0()
{
}
weak_alias(dummy_0, __pthread_tsd_run_dtors);

static void cleanup_fromsig(void *p)
{
	pthread_t self = __pthread_self();
	__pthread_tsd_run_dtors();
	self->cancel = 0;
	self->cancelbuf = 0;
	self->canceldisable = 0;
	self->cancelasync = 0;
	self->unblock_cancel = 0;
	__reset_tls();
	longjmp(p, 1);
}

static void timer_handler(int sig, siginfo_t *si, void *ctx)
{
	pthread_t self = __pthread_self();
	jmp_buf jb;
	void (*notify)(union sigval) = (void (*)(union sigval))self->start;
	union sigval val = { .sival_ptr = self->start_arg };

	if (!setjmp(jb) && si->si_code == SI_TIMER) {
		pthread_cleanup_push(cleanup_fromsig, jb);
		notify(val);
		pthread_cleanup_pop(1);
	}
}

static void install_handler()
{
	struct sigaction sa = {
		.sa_sigaction = timer_handler,
		.sa_flags = SA_SIGINFO | SA_RESTART
	};
	__libc_sigaction(SIGTIMER, &sa, 0);
}

static void *start(void *arg)
{
	pthread_t self = __pthread_self();
	struct start_args *args = arg;
	int id;

	/* Reuse no-longer-needed thread structure fields to avoid
	 * needing the timer address in the signal handler. */
	self->start = (void *(*)(void *))args->sev->sigev_notify_function;
	self->start_arg = args->sev->sigev_value.sival_ptr;

	pthread_barrier_wait(&args->b);
	if ((id = self->timer_id) >= 0) {
		__syscall(SYS_rt_sigprocmask, SIG_UNBLOCK,
			SIGTIMER_SET, 0, _NSIG/8);
		__wait(&self->timer_id, 0, id, 1);
		__syscall(SYS_timer_delete, id);
	}
	return 0;
}

int timer_create(clockid_t clk, struct sigevent *restrict evp, timer_t *restrict res)
{
	static pthread_once_t once = PTHREAD_ONCE_INIT;
	pthread_t td;
	pthread_attr_t attr;
	int r;
	struct start_args args;
	struct ksigevent ksev, *ksevp=0;
	int timerid;
	sigset_t set;

	switch (evp ? evp->sigev_notify : SIGEV_SIGNAL) {
	case SIGEV_NONE:
	case SIGEV_SIGNAL:
		if (evp) {
			ksev.sigev_value = evp->sigev_value;
			ksev.sigev_signo = evp->sigev_signo;
			ksev.sigev_notify = evp->sigev_notify;
			ksev.sigev_tid = 0;
			ksevp = &ksev;
		}
		if (syscall(SYS_timer_create, clk, ksevp, &timerid) < 0)
			return -1;
		*res = (void *)(intptr_t)timerid;
		break;
	case SIGEV_THREAD:
		pthread_once(&once, install_handler);
		if (evp->sigev_notify_attributes)
			attr = *evp->sigev_notify_attributes;
		else
			pthread_attr_init(&attr);
		pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
		pthread_barrier_init(&args.b, 0, 2);
		args.sev = evp;

		__block_app_sigs(&set);
		r = pthread_create(&td, &attr, start, &args);
		__restore_sigs(&set);
		if (r) {
			errno = r;
			return -1;
		}

		ksev.sigev_value.sival_ptr = 0;
		ksev.sigev_signo = SIGTIMER;
		ksev.sigev_notify = 4; /* SIGEV_THREAD_ID */
		ksev.sigev_tid = td->tid;
		if (syscall(SYS_timer_create, clk, &ksev, &timerid) < 0)
			timerid = -1;
		td->timer_id = timerid;
		pthread_barrier_wait(&args.b);
		if (timerid < 0) return -1;
		*res = (void *)(INTPTR_MIN | (uintptr_t)td>>1);
		break;
	default:
		errno = EINVAL;
		return -1;
	}

	return 0;
}
