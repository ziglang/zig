#include <signal.h>

int __libc_current_sigrtmax()
{
	return _NSIG-1;
}
