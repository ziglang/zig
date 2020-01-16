#define _GNU_SOURCE
#include <sys/sem.h>
#include <errno.h>
#include "syscall.h"
#include "ipc.h"

#define IS32BIT(x) !((x)+0x80000000ULL>>32)
#define CLAMP(x) (int)(IS32BIT(x) ? (x) : 0x7fffffffU+((0ULL+(x))>>63))

#if !defined(SYS_semtimedop) && !defined(SYS_ipc)
#define NO_TIME32 1
#else
#define NO_TIME32 0
#endif

int semtimedop(int id, struct sembuf *buf, size_t n, const struct timespec *ts)
{
#ifdef SYS_semtimedop_time64
	time_t s = ts ? ts->tv_sec : 0;
	long ns = ts ? ts->tv_nsec : 0;
	int r = -ENOSYS;
	if (NO_TIME32 || !IS32BIT(s))
		r = __syscall(SYS_semtimedop_time64, id, buf, n,
			ts ? ((long long[]){s, ns}) : 0);
	if (NO_TIME32 || r!=-ENOSYS) return __syscall_ret(r);
	ts = ts ? (void *)(long[]){CLAMP(s), ns} : 0;
#endif
#if defined(SYS_ipc)
	return syscall(SYS_ipc, IPCOP_semtimedop, id, n, 0, buf, ts);
#elif defined(SYS_semtimedop)
	return syscall(SYS_semtimedop, id, buf, n, ts);
#else
	return __syscall_ret(-ENOSYS);
#endif
}
