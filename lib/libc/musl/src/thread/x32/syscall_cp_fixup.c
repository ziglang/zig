#include <sys/syscall.h>
#include <features.h>

hidden long __syscall_cp_internal(volatile void*, long long, long long,
                                  long long, long long, long long,
                                  long long, long long);

struct __timespec { long long tv_sec; long tv_nsec; };
struct __timespec_kernel { long long tv_sec; long long tv_nsec; };
#define __tsc(X) ((struct __timespec*)(unsigned long)(X))
#define __fixup(X) do { if(X) { \
	ts->tv_sec = __tsc(X)->tv_sec; \
	ts->tv_nsec = __tsc(X)->tv_nsec; \
	(X) = (unsigned long)ts; } } while(0)

hidden long __syscall_cp_asm (volatile void * foo, long long n, long long a1,
                              long long a2, long long a3, long long a4,
                              long long a5, long long a6)
{
	struct __timespec_kernel ts[1];
	switch (n) {
	case SYS_mq_timedsend: case SYS_mq_timedreceive: case SYS_pselect6:
		__fixup(a5);
		break;
	case SYS_futex:
		if((a2 & (~128 /* FUTEX_PRIVATE_FLAG */)) == 0 /* FUTEX_WAIT */)
			__fixup(a4);
		break;
	case SYS_clock_nanosleep:
	case SYS_rt_sigtimedwait: case SYS_ppoll:
		__fixup(a3);
		break;
	case SYS_nanosleep:
		__fixup(a1);
		break;
	}
	return __syscall_cp_internal(foo, n, a1, a2, a3, a4, a5, a6);
}

