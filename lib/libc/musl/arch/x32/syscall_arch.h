#define __SYSCALL_LL_E(x) (x)
#define __SYSCALL_LL_O(x) (x)

#define __scc(X) sizeof(1?(X):0ULL) < 8 ? (unsigned long) (X) : (long long) (X)
typedef long long syscall_arg_t;

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
	__asm__ __volatile__ ("syscall" : "=a"(ret) : "a"(n), "D"(a1), "S"(a2)
					: "rcx", "r11", "memory");
	return ret;
}

static __inline long __syscall3(long long n, long long a1, long long a2, long long a3)
{
	unsigned long ret;
	__asm__ __volatile__ ("syscall" : "=a"(ret) : "a"(n), "D"(a1), "S"(a2),
						  "d"(a3) : "rcx", "r11", "memory");
	return ret;
}

static __inline long __syscall4(long long n, long long a1, long long a2, long long a3,
                                     long long a4_)
{
	unsigned long ret;
	register long long a4 __asm__("r10") = a4_;
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
	__asm__ __volatile__ ("syscall" : "=a"(ret) : "a"(n), "D"(a1), "S"(a2),
					  "d"(a3), "r"(a4), "r"(a5), "r"(a6) : "rcx", "r11", "memory");
	return ret;
}

#undef SYS_futimesat

#define SYS_clock_gettime64 SYS_clock_gettime
#define SYS_clock_settime64 SYS_clock_settime
#define SYS_clock_adjtime64 SYS_clock_adjtime
#define SYS_clock_nanosleep_time64 SYS_clock_nanosleep
#define SYS_timer_gettime64 SYS_timer_gettime
#define SYS_timer_settime64 SYS_timer_settime
#define SYS_timerfd_gettime64 SYS_timerfd_gettime
#define SYS_timerfd_settime64 SYS_timerfd_settime
#define SYS_utimensat_time64 SYS_utimensat
#define SYS_pselect6_time64 SYS_pselect6
#define SYS_ppoll_time64 SYS_ppoll
#define SYS_recvmmsg_time64 SYS_recvmmsg
#define SYS_mq_timedsend_time64 SYS_mq_timedsend
#define SYS_mq_timedreceive_time64 SYS_mq_timedreceive
#define SYS_semtimedop_time64 SYS_semtimedop
#define SYS_rt_sigtimedwait_time64 SYS_rt_sigtimedwait
#define SYS_futex_time64 SYS_futex
#define SYS_sched_rr_get_interval_time64 SYS_sched_rr_get_interval
#define SYS_getrusage_time64 SYS_getrusage
#define SYS_wait4_time64 SYS_wait4

#define IPC_64 0
