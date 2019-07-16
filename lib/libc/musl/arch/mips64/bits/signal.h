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
	unsigned long long sc_regs[32];
	unsigned long long sc_fpregs[32];
	unsigned long long sc_mdhi;
	unsigned long long sc_hi1;
	unsigned long long sc_hi2;
	unsigned long long sc_hi3;
	unsigned long long sc_mdlo;
	unsigned long long sc_lo1;
	unsigned long long sc_lo2;
	unsigned long long sc_lo3;
	unsigned long long sc_pc;
	unsigned int sc_fpc_csr;
	unsigned int sc_used_math;
	unsigned int sc_dsp;
	unsigned int sc_reserved;
};

typedef struct {
	gregset_t gregs;
	fpregset_t fpregs;
	greg_t mdhi;
	greg_t hi1;
	greg_t hi2;
	greg_t hi3;
	greg_t mdlo;
	greg_t lo1;
	greg_t lo2;
	greg_t lo3;
	greg_t pc;
	unsigned int fpc_csr;
	unsigned int used_math;
	unsigned int dsp;
	unsigned int reserved;
} mcontext_t;

#else
typedef struct {
	unsigned long long __mc1[32];
	double __mc2[32];
	unsigned long long __mc3[9];
	unsigned __mc4[4];
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
#define SIGSTKFLT 7
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
