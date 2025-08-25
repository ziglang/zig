#if defined(_POSIX_SOURCE) || defined(_POSIX_C_SOURCE) \
 || defined(_XOPEN_SOURCE) || defined(_GNU_SOURCE) || defined(_BSD_SOURCE)

#if defined(_XOPEN_SOURCE) || defined(_GNU_SOURCE) || defined(_BSD_SOURCE)
#define MINSIGSTKSZ 4096
#define SIGSTKSZ 10240
#endif

#if defined(_GNU_SOURCE) || defined(_BSD_SOURCE)

typedef unsigned long greg_t, gregset_t[48];

typedef struct {
	double fpregs[32];
	double fpscr;
	unsigned _pad[2];
} fpregset_t;

typedef struct {
	unsigned vrregs[32][4];
	unsigned vrsave;
	unsigned _pad[2];
	unsigned vscr;
} vrregset_t;

struct sigcontext {
	unsigned long _unused[4];
	int signal;
	unsigned long handler;
	unsigned long oldmask;
	struct pt_regs *regs;
};

typedef struct {
	gregset_t gregs;
	fpregset_t fpregs;
	vrregset_t vrregs
#ifdef __GNUC__
	__attribute__((__aligned__(16)))
#endif
	;
} mcontext_t;

#else

typedef struct {
	long __regs[48+68+4*32+4]
#ifdef __GNUC__
	__attribute__((__aligned__(16)))
#endif
	;
} mcontext_t;

#endif

struct sigaltstack {
	void *ss_sp;
	int ss_flags;
	size_t ss_size;
};

typedef struct __ucontext {
	unsigned long uc_flags;
	struct __ucontext *uc_link;
	stack_t uc_stack;
	int uc_pad[7];
	mcontext_t *uc_regs;
	sigset_t uc_sigmask;
        int             uc_pad2[3];
	mcontext_t uc_mcontext;
} ucontext_t;

#define SA_NOCLDSTOP  1U
#define SA_NOCLDWAIT  2U
#define SA_SIGINFO    4U
#define SA_ONSTACK    0x08000000U
#define SA_RESTART    0x10000000U
#define SA_NODEFER    0x40000000U
#define SA_RESETHAND  0x80000000U
#define SA_RESTORER   0x04000000U

#endif

#define SIGHUP    1
#define SIGINT    2
#define SIGQUIT   3
#define SIGILL    4
#define SIGTRAP   5
#define SIGABRT   6
#define SIGIOT    SIGABRT
#define SIGBUS    7
#define SIGFPE    8
#define SIGKILL   9
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
#define SIGPOLL   29
#define SIGPWR    30
#define SIGSYS    31
#define SIGUNUSED SIGSYS

#define _NSIG 65