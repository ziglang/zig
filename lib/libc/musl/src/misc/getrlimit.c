#include <sys/resource.h>
#include <errno.h>
#include "syscall.h"

#define FIX(x) do{ if ((x)>=SYSCALL_RLIM_INFINITY) (x)=RLIM_INFINITY; }while(0)

int getrlimit(int resource, struct rlimit *rlim)
{
	unsigned long k_rlim[2];
	int ret = syscall(SYS_prlimit64, 0, resource, 0, rlim);
	if (!ret) {
		FIX(rlim->rlim_cur);
		FIX(rlim->rlim_max);
	}
	if (!ret || errno != ENOSYS)
		return ret;
	if (syscall(SYS_getrlimit, resource, k_rlim) < 0)
		return -1;
	rlim->rlim_cur = k_rlim[0] == -1UL ? RLIM_INFINITY : k_rlim[0];
	rlim->rlim_max = k_rlim[1] == -1UL ? RLIM_INFINITY : k_rlim[1];
	FIX(rlim->rlim_cur);
	FIX(rlim->rlim_max);
	return 0;
}

weak_alias(getrlimit, getrlimit64);
