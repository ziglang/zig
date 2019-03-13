#include <signal.h>

int siginterrupt(int sig, int flag)
{
	struct sigaction sa;

	sigaction(sig, 0, &sa);
	if (flag) sa.sa_flags &= ~SA_RESTART;
	else sa.sa_flags |= SA_RESTART;

	return sigaction(sig, &sa, 0);
}
