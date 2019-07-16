#include <signal.h>

int sigismember(const sigset_t *set, int sig)
{
	unsigned s = sig-1;
	if (s >= _NSIG-1) return 0;
	return !!(set->__bits[s/8/sizeof *set->__bits] & 1UL<<(s&8*sizeof *set->__bits-1));
}
