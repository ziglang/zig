#define __SYSCALL_LL_E(x) (x)
#define __SYSCALL_LL_O(x) (x)

#define __scc(X) sizeof(1?(X):0ULL) < 8 ? (unsigned long) (X) : (long long) (X)
typedef long long syscall_arg_t;
struct __timespec { long long tv_sec; long tv_nsec; };
struct __timespec_kernel { long long tv_sec; long long tv_nsec; };
#define __tsc(X) ((struct __timespec*)(unsigned long)(X))
#define __fixup(X) do { if(X) { \
	ts->tv_sec = __tsc(X)->tv_sec; \
	ts->tv_nsec = __tsc(X)->tv_nsec; \
	(X) = (unsigned long)ts; } } while(0)
#define __fixup_case_2 \
	case SYS_nanosleep: \
		__fixup(a1); break; \
	case SYS_clock_settime: \
		__fixup(a2); break;
#define __fixup_case_3 \
	case SYS_clock_nanosleep: case SYS_rt_sigtimedwait: case SYS_ppoll: \
		__fixup(a3); break; \
	case SYS_utimensat: \
		if(a3) { \
			ts[0].tv_sec = __tsc(a3)[0].tv_sec; \
			ts[0].tv_nsec = __tsc(a3)[0].tv_nsec; \
			ts[1].tv_sec = __tsc(a3)[1].tv_sec; \
			ts[1].tv_nsec = __tsc(a3)[1].tv_nsec; \
			a3 = (unsigned long)ts; \
		} break;
#define __fixup_case_4 \
	case SYS_futex: \
		if((a2 & (~128 /* FUTEX_PRIVATE_FLAG */)) == 0 /* FUTEX_WAIT */) __fixup(a4); break;
#define __fixup_case_5 \
	case SYS_mq_timedsend: case SYS_mq_timedreceive: case SYS_pselect6: \
		__fixup(a5); break;

static __inline long __syscall0(long long n)
{
	unsigned long ret;
	__asm__ __volatile__ ("syscall" : "=a"(ret) : "a"(n) : "rcx", "r11", "memory");
	return ret;
}

static __inline long __syscall1(long long n, long long a1)
{
	unsigned long ret;
	__asm__ __volatile__ ("syscall" : "=a"(ret) : "a"(n), "D"(a1) : "rcx", "r11", "memory");
	return ret;
}

static __inline long __syscall2(long long n, long long a1, long long a2)
{
	unsigned long ret;
	struct __timespec_kernel ts[1];
	switch (n) {
		__fixup_case_2;
	}
	__asm__ __volatile__ ("syscall" : "=a"(ret) : "a"(n), "D"(a1), "S"(a2)
					: "rcx", "r11", "memory");
	return ret;
}

static __inline long __syscall3(long long n, long long a1, long long a2, long long a3)
{
	unsigned long ret;
	struct __timespec_kernel ts[2];
	switch (n) {
		__fixup_case_2;
		__fixup_case_3;
	}
	__asm__ __volatile__ ("syscall" : "=a"(ret) : "a"(n), "D"(a1), "S"(a2),
						  "d"(a3) : "rcx", "r11", "memory");
	return ret;
}

static __inline long __syscall4(long long n, long long a1, long long a2, long long a3,
                                     long long a4_)
{
	unsigned long ret;
	register long long a4 __asm__("r10") = a4_;
	struct __timespec_kernel ts[2];
	switch (n) {
		__fixup_case_2;
		__fixup_case_3;
		__fixup_case_4;
	}
	__asm__ __volatile__ ("syscall" : "=a"(ret) : "a"(n), "D"(a1), "S"(a2),
					  "d"(a3), "r"(a4): "rcx", "r11", "memory");
	return ret;
}

static __inline long __syscall5(long long n, long long a1, long long a2, long long a3,
                                     long long a4_, long long a5_)
{
	unsigned long ret;
	register long long a4 __asm__("r10") = a4_;
	register long long a5 __asm__("r8") = a5_;
	struct __timespec_kernel ts[2];
	switch (n) {
		__fixup_case_2;
		__fixup_case_3;
		__fixup_case_4;
		__fixup_case_5;
	}
	__asm__ __volatile__ ("syscall" : "=a"(ret) : "a"(n), "D"(a1), "S"(a2),
					  "d"(a3), "r"(a4), "r"(a5) : "rcx", "r11", "memory");
	return ret;
}

static __inline long __syscall6(long long n, long long a1, long long a2, long long a3,
                                     long long a4_, long long a5_, long long a6_)
{
	unsigned long ret;
	register long long a4 __asm__("r10") = a4_;
	register long long a5 __asm__("r8") = a5_;
	register long long a6 __asm__("r9") = a6_;
	struct __timespec_kernel ts[2];
	switch (n) {
		__fixup_case_2;
		__fixup_case_3;
		__fixup_case_4;
		__fixup_case_5;
	}
	__asm__ __volatile__ ("syscall" : "=a"(ret) : "a"(n), "D"(a1), "S"(a2),
					  "d"(a3), "r"(a4), "r"(a5), "r"(a6) : "rcx", "r11", "memory");
	return ret;
}
