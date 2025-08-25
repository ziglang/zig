#if defined(_POSIX_SOURCE) || defined(_POSIX_C_SOURCE) \
 || defined(_XOPEN_SOURCE) || defined(_GNU_SOURCE) || defined(_BSD_SOURCE)

#if defined(_XOPEN_SOURCE) || defined(_GNU_SOURCE) || defined(_BSD_SOURCE)
#define MINSIGSTKSZ 4096
#define SIGSTKSZ 16384
#endif

#if defined(_GNU_SOURCE)
#define LARCH_NGREG 32
#define LARCH_REG_RA 1
#define LARCH_REG_SP 3
#define LARCH_REG_S0 23
#define LARCH_REG_S1 24
#define LARCH_REG_A0 4
#define LARCH_REG_S2 25
#define LARCH_REG_NARGS 8
#endif

#if defined(_GNU_SOURCE) || defined(_BSD_SOURCE)
typedef unsigned long greg_t, gregset_t[32];

struct sigcontext {
	unsigned long sc_pc;
	unsigned long sc_regs[32];
	unsigned sc_flags;
	unsigned long sc_extcontext[] __attribute__((__aligned__(16)));
};
#endif

typedef struct {
	unsigned long __pc;
	unsigned long __gregs[32];
	unsigned __flags;
	unsigned long __extcontext[] __attribute__((__aligned__(16)));
} mcontext_t;

struct sigaltstack {
	void *ss_sp;
	int ss_flags;
	size_t ss_size;
};

typedef struct __ucontext
{
	unsigned long uc_flags;
	struct __ucontext *uc_link;
	stack_t uc_stack;
	sigset_t uc_sigmask;
	long __uc_pad;
	mcontext_t uc_mcontext;
} ucontext_t;

#define __uc_flags uc_flags

#define SA_NOCLDSTOP 1
#define SA_NOCLDWAIT 2
#define SA_SIGINFO   4
#define SA_ONSTACK   0x08000000
#define SA_RESTART   0x10000000
#define SA_NODEFER   0x40000000
#define SA_RESETHAND 0x80000000

#endif

#define SIGHUP     1
#define SIGINT     2
#define SIGQUIT    3
#define SIGILL     4
#define SIGTRAP    5
#define SIGABRT    6
#define SIGIOT     SIGABRT
#define SIGBUS     7
#define SIGFPE     8
#define SIGKILL    9
#define SIGUSR1   10
#define SIGSEGV   11
#define SIGUSR2   12
#define SIGPIPE   13
#define SIGALRM   14
#define SIGTERM   15
#define SIGSTKFLT 16
#define SIGCHLD   17
#define SIGCONT   18
#define SIGSTOP   19
#define SIGTSTP   20
#define SIGTTIN   21
#define SIGTTOU   22
#define SIGURG    23
#define SIGXCPU   24
#define SIGXFSZ   25
#define SIGVTALRM 26
#define SIGPROF   27
#define SIGWINCH  28
#define SIGIO     29
#define SIGPOLL   SIGIO
#define SIGPWR    30
#define SIGSYS    31
#define SIGUNUSED SIGSYS

#define _NSIG 65