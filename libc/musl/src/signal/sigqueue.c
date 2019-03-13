#include <signal.h>
#include <string.h>
#include <unistd.h>
#include "syscall.h"
#include "pthread_impl.h"

int sigqueue(pid_t pid, int sig, const union sigval value)
{
	siginfo_t si;
	sigset_t set;
	int r;
	memset(&si, 0, sizeof si);
	si.si_signo = sig;
	si.si_code = SI_QUEUE;
	si.si_value = value;
	si.si_uid = getuid();
	__block_app_sigs(&set);
	si.si_pid = getpid();
	r = syscall(SYS_rt_sigqueueinfo, pid, sig, &si);
	__restore_sigs(&set);
	return r;
}
