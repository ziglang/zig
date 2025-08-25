#include <pty.h>
#include <utmp.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <pthread.h>

int forkpty(int *pm, char *name, const struct termios *tio, const struct winsize *ws)
{
	int m, s, ec=0, p[2], cs;
	pid_t pid=-1;
	sigset_t set, oldset;

	if (openpty(&m, &s, name, tio, ws) < 0) return -1;

	sigfillset(&set);
	pthread_sigmask(SIG_BLOCK, &set, &oldset);
	pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cs);

	if (pipe2(p, O_CLOEXEC)) {
		close(s);
		goto out;
	}

	pid = fork();
	if (!pid) {
		close(m);
		close(p[0]);
		if (login_tty(s)) {
			write(p[1], &errno, sizeof errno);
			_exit(127);
		}
		close(p[1]);
		pthread_setcancelstate(cs, 0);
		pthread_sigmask(SIG_SETMASK, &oldset, 0);
		return 0;
	}
	close(s);
	close(p[1]);
	if (read(p[0], &ec, sizeof ec) > 0) {
		int status;
		waitpid(pid, &status, 0);
		pid = -1;
		errno = ec;
	}
	close(p[0]);

out:
	if (pid > 0) *pm = m;
	else close(m);

	pthread_setcancelstate(cs, 0);
	pthread_sigmask(SIG_SETMASK, &oldset, 0);

	return pid;
}
