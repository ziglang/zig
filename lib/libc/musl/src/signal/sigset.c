#include <signal.h>

void (*sigset(int sig, void (*handler)(int)))(int)
{
	struct sigaction sa, sa_old;
	sigset_t mask, mask_old;

	sigemptyset(&mask);
	if (sigaddset(&mask, sig) < 0)
		return SIG_ERR;
	
	if (handler == SIG_HOLD) {
		if (sigaction(sig, 0, &sa_old) < 0)
			return SIG_ERR;
		if (sigprocmask(SIG_BLOCK, &mask, &mask_old) < 0)
			return SIG_ERR;
	} else {
		sa.sa_handler = handler;
		sa.sa_flags = 0;
		sigemptyset(&sa.sa_mask);
		if (sigaction(sig, &sa, &sa_old) < 0)
			return SIG_ERR;
		if (sigprocmask(SIG_UNBLOCK, &mask, &mask_old) < 0)
			return SIG_ERR;
	}
	return sigismember(&mask_old, sig) ? SIG_HOLD : sa_old.sa_handler;
}
