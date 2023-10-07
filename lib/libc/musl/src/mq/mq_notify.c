#include <mqueue.h>
#include <pthread.h>
#include <errno.h>
#include <sys/socket.h>
#include <signal.h>
#include <unistd.h>
#include <semaphore.h>
#include "syscall.h"

struct args {
	sem_t sem;
	int sock;
	mqd_t mqd;
	int err;
	const struct sigevent *sev;
};

static void *start(void *p)
{
	struct args *args = p;
	char buf[32];
	ssize_t n;
	int s = args->sock;
	void (*func)(union sigval) = args->sev->sigev_notify_function;
	union sigval val = args->sev->sigev_value;
	struct sigevent sev2;
	static const char zeros[32];
	int err;

	sev2.sigev_notify = SIGEV_THREAD;
	sev2.sigev_signo = s;
	sev2.sigev_value.sival_ptr = (void *)&zeros;

	args->err = err = -__syscall(SYS_mq_notify, args->mqd, &sev2);
	sem_post(&args->sem);
	if (err) return 0;

	pthread_detach(pthread_self());
	n = recv(s, buf, sizeof(buf), MSG_NOSIGNAL|MSG_WAITALL);
	close(s);
	if (n==sizeof buf && buf[sizeof buf - 1] == 1)
		func(val);
	return 0;
}

int mq_notify(mqd_t mqd, const struct sigevent *sev)
{
	struct args args = { .sev = sev };
	pthread_attr_t attr;
	pthread_t td;
	int s;
	int cs;
	sigset_t allmask, origmask;

	if (!sev || sev->sigev_notify != SIGEV_THREAD)
		return syscall(SYS_mq_notify, mqd, sev);

	s = socket(AF_NETLINK, SOCK_RAW|SOCK_CLOEXEC, 0);
	if (s < 0) return -1;
	args.sock = s;
	args.mqd = mqd;

	if (sev->sigev_notify_attributes) attr = *sev->sigev_notify_attributes;
	else pthread_attr_init(&attr);
	pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);
	sem_init(&args.sem, 0, 0);

	sigfillset(&allmask);
	pthread_sigmask(SIG_BLOCK, &allmask, &origmask);
	if (pthread_create(&td, &attr, start, &args)) {
		__syscall(SYS_close, s);
		pthread_sigmask(SIG_SETMASK, &origmask, 0);
		errno = EAGAIN;
		return -1;
	}
	pthread_sigmask(SIG_SETMASK, &origmask, 0);

	pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cs);
	sem_wait(&args.sem);
	sem_destroy(&args.sem);

	if (args.err) {
		__syscall(SYS_close, s);
		pthread_join(td, 0);
		pthread_setcancelstate(cs, 0);
		errno = args.err;
		return -1;
	}

	pthread_setcancelstate(cs, 0);
	return 0;
}
