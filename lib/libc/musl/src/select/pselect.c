#include <sys/select.h>
#include <signal.h>
#include <stdint.h>
#include <errno.h>
#include "syscall.h"

#define IS32BIT(x) !((x)+0x80000000ULL>>32)
#define CLAMP(x) (int)(IS32BIT(x) ? (x) : 0x7fffffffU+((0ULL+(x))>>63))

int pselect(int n, fd_set *restrict rfds, fd_set *restrict wfds, fd_set *restrict efds, const struct timespec *restrict ts, const sigset_t *restrict mask)
{
	syscall_arg_t data[2] = { (uintptr_t)mask, _NSIG/8 };
	time_t s = ts ? ts->tv_sec : 0;
	long ns = ts ? ts->tv_nsec : 0;
#ifdef SYS_pselect6_time64
	int r = -ENOSYS;
	if (SYS_pselect6 == SYS_pselect6_time64 || !IS32BIT(s))
		r = __syscall_cp(SYS_pselect6_time64, n, rfds, wfds, efds,
			ts ? ((long long[]){s, ns}) : 0, data);
	if (SYS_pselect6 == SYS_pselect6_time64 || r!=-ENOSYS)
		return __syscall_ret(r);
	s = CLAMP(s);
#endif
	return syscall_cp(SYS_pselect6, n, rfds, wfds, efds,
		ts ? ((long[]){s, ns}) : 0, data);
}
