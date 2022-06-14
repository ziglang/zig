#include "pthread_impl.h"
#include "syscall.h"
#include <signal.h>

static const unsigned long all_mask[] = {
#if ULONG_MAX == 0xffffffff && _NSIG > 65
	-1UL, -1UL, -1UL, -1UL
#elif ULONG_MAX == 0xffffffff || _NSIG > 65
	-1UL, -1UL
#else
	-1UL
#endif
};

static const unsigned long app_mask[] = {
#if ULONG_MAX == 0xffffffff
#if _NSIG == 65
	0x7fffffff, 0xfffffffc
#else
	0x7fffffff, 0xfffffffc, -1UL, -1UL
#endif
#else
#if _NSIG == 65
	0xfffffffc7fffffff
#else
	0xfffffffc7fffffff, -1UL
#endif
#endif
};

void __block_all_sigs(void *set)
{
	__syscall(SYS_rt_sigprocmask, SIG_BLOCK, &all_mask, set, _NSIG/8);
}

void __block_app_sigs(void *set)
{
	__syscall(SYS_rt_sigprocmask, SIG_BLOCK, &app_mask, set, _NSIG/8);
}

void __restore_sigs(void *set)
{
	__syscall(SYS_rt_sigprocmask, SIG_SETMASK, set, 0, _NSIG/8);
}
