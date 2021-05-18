#if defined(_POSIX_SOURCE) || defined(_POSIX_C_SOURCE) \
 || defined(_XOPEN_SOURCE) || defined(_GNU_SOURCE) || defined(_BSD_SOURCE)

#if defined(_XOPEN_SOURCE) || defined(_GNU_SOURCE) || defined(_BSD_SOURCE)
#define MINSIGSTKSZ 2048
#define SIGSTKSZ 8192
#endif

#if defined(_GNU_SOURCE) || defined(_BSD_SOURCE)
typedef unsigned long long greg_t, gregset_t[32];
typedef struct {
	union {
		double fp_dregs[32];
		struct {
			float _fp_fregs;
			unsigned _fp_pad;
		} fp_fregs[32];
	} fp_r;
} fpregset_t;
struct sigcontext {
	unsigned sc_regmask, sc_status;
	unsigned long long sc_pc;
	gregset_t sc_regs;
	fpregset_t sc_fpregs;
	unsigned sc_ownedfp, sc_fpc_csr, sc_fpc_eir, sc_used_math, sc_dsp;
	unsigned long long sc_mdhi, sc_mdlo;
	unsigned long sc_hi1, sc_lo1, sc_hi2, sc_lo2, sc_hi3, sc_lo3;
};
typedef struct {
	unsigned regmask, status;
	unsigned long long pc;
	gregset_t gregs;
	fpregset_t fpregs;
	unsigned ownedfp, fpc_csr, fpc_eir, used_math, dsp;
	unsigned long long mdhi, mdlo;
	unsigned long hi1, lo1, hi2, lo2, hi3, lo3;
} mcontext_t;
#else
typedef struct {
	unsigned __mc1[2];
	unsigned long long __mc2[65];
	unsigned __mc3[5];
	unsigned long long __mc4[2];
	unsigned __mc5[6];
} mcontext_t;
#endif

struct sigaltstack {
	void *ss_sp;
	size_t ss_size;
	int ss_flags;
};

typedef struct __ucontext {
	unsigned long uc_flags;
	struct __ucontext *uc_link;
	stack_t uc_stack;
	mcontext_t uc_mcontext;
	sigset_t uc_sigmask;
} ucontext_t;

#define SA_NOCLDSTOP  1
#define SA_NOCLDWAIT  0x10000
#define SA_SIGINFO    8
#define SA_ONSTACK    0x08000000
#define SA_RESTART    0x10000000
#define SA_NODEFER    0x40000000
#define SA_RESETHAND  0x80000000
#define SA_RESTORER   0x04000000

#undef SIG_BLOCK
#undef SIG_UNBLOCK
#undef SIG_SETMASK
#define SIG_BLOCK     1
#define SIG_UNBLOCK   2
#define SIG_SETMASK   3

#undef SI_ASYNCIO
#undef SI_MESGQ
#undef SI_TIMER
#define SI_ASYNCIO (-2)
#define SI_MESGQ (-4)
#define SI_TIMER (-3)

#define __SI_SWAP_ERRNO_CODE

#endif

#define SIGHUP    1
#define SIGINT    2
#define SIGQUIT   3
#define SIGILL    4
#define SIGTRAP   5
#define SIGABRT   6
#define SIGIOT    SIGABRT
#define SIGEMT    7
#define SIGFPE    8
#define SIGKILL   9
#define SIGBUS    10
#define SIGSEGV   11
#define SIGSYS    12
#define SIGPIPE   13
#define SIGALRM   14
#define SIGTERM   15
#define SIGUSR1   16
#define SIGUSR2   17
#define SIGCHLD   18
#define SIGPWR    19
#define SIGWINCH  20
#define SIGURG    21
#define SIGIO     22
#define SIGPOLL   SIGIO
#define SIGSTOP   23
#define SIGTSTP   24
#define SIGCONT   25
#define SIGTTIN   26
#define SIGTTOU   27
#define SIGVTALRM 28
#define SIGPROF   29
#define SIGXCPU   30
#define SIGXFSZ   31
#define SIGUNUSED SIGSYS

#define _NSIG 128
