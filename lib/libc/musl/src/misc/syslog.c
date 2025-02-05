#include <stdarg.h>
#include <sys/socket.h>
#include <stdio.h>
#include <unistd.h>
#include <syslog.h>
#include <time.h>
#include <signal.h>
#include <string.h>
#include <pthread.h>
#include <errno.h>
#include <fcntl.h>
#include "lock.h"
#include "fork_impl.h"
#include "locale_impl.h"

static volatile int lock[1];
static char log_ident[32];
static int log_opt;
static int log_facility = LOG_USER;
static int log_mask = 0xff;
static int log_fd = -1;
volatile int *const __syslog_lockptr = lock;

int setlogmask(int maskpri)
{
	LOCK(lock);
	int ret = log_mask;
	if (maskpri) log_mask = maskpri;
	UNLOCK(lock);
	return ret;
}

static const struct {
	short sun_family;
	char sun_path[9];
} log_addr = {
	AF_UNIX,
	"/dev/log"
};

void closelog(void)
{
	int cs;
	pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cs);
	LOCK(lock);
	close(log_fd);
	log_fd = -1;
	UNLOCK(lock);
	pthread_setcancelstate(cs, 0);
}

static void __openlog()
{
	log_fd = socket(AF_UNIX, SOCK_DGRAM|SOCK_CLOEXEC, 0);
	if (log_fd >= 0) connect(log_fd, (void *)&log_addr, sizeof log_addr);
}

void openlog(const char *ident, int opt, int facility)
{
	int cs;
	pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cs);
	LOCK(lock);

	if (ident) {
		size_t n = strnlen(ident, sizeof log_ident - 1);
		memcpy(log_ident, ident, n);
		log_ident[n] = 0;
	} else {
		log_ident[0] = 0;
	}
	log_opt = opt;
	log_facility = facility;

	if ((opt & LOG_NDELAY) && log_fd<0) __openlog();

	UNLOCK(lock);
	pthread_setcancelstate(cs, 0);
}

static int is_lost_conn(int e)
{
	return e==ECONNREFUSED || e==ECONNRESET || e==ENOTCONN || e==EPIPE;
}

static void _vsyslog(int priority, const char *message, va_list ap)
{
	char timebuf[16];
	time_t now;
	struct tm tm;
	char buf[1024];
	int errno_save = errno;
	int pid;
	int l, l2;
	int hlen;
	int fd;

	if (log_fd < 0) __openlog();

	if (!(priority & LOG_FACMASK)) priority |= log_facility;

	now = time(NULL);
	gmtime_r(&now, &tm);
	strftime_l(timebuf, sizeof timebuf, "%b %e %T", &tm, C_LOCALE);

	pid = (log_opt & LOG_PID) ? getpid() : 0;
	l = snprintf(buf, sizeof buf, "<%d>%s %n%s%s%.0d%s: ",
		priority, timebuf, &hlen, log_ident, "["+!pid, pid, "]"+!pid);
	errno = errno_save;
	l2 = vsnprintf(buf+l, sizeof buf - l, message, ap);
	if (l2 >= 0) {
		if (l2 >= sizeof buf - l) l = sizeof buf - 1;
		else l += l2;
		if (buf[l-1] != '\n') buf[l++] = '\n';
		if (send(log_fd, buf, l, 0) < 0 && (!is_lost_conn(errno)
		    || connect(log_fd, (void *)&log_addr, sizeof log_addr) < 0
		    || send(log_fd, buf, l, 0) < 0)
		    && (log_opt & LOG_CONS)) {
			fd = open("/dev/console", O_WRONLY|O_NOCTTY|O_CLOEXEC);
			if (fd >= 0) {
				dprintf(fd, "%.*s", l-hlen, buf+hlen);
				close(fd);
			}
		}
		if (log_opt & LOG_PERROR) dprintf(2, "%.*s", l-hlen, buf+hlen);
	}
}

static void __vsyslog(int priority, const char *message, va_list ap)
{
	int cs;
	if (!(log_mask & LOG_MASK(priority&7)) || (priority&~0x3ff)) return;
	pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cs);
	LOCK(lock);
	_vsyslog(priority, message, ap);
	UNLOCK(lock);
	pthread_setcancelstate(cs, 0);
}

void syslog(int priority, const char *message, ...)
{
	va_list ap;
	va_start(ap, message);
	__vsyslog(priority, message, ap);
	va_end(ap);
}

weak_alias(__vsyslog, vsyslog);
