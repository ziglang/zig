#include <signal.h>

int sigwaitinfo(const sigset_t *restrict mask, siginfo_t *restrict si)
{
	return sigtimedwait(mask, si, 0);
}
