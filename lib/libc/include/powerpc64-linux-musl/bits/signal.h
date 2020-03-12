#if defined(_POSIX_SOURCE) || defined(_POSIX_C_SOURCE) \
 || defined(_XOPEN_SOURCE) || defined(_GNU_SOURCE) || defined(_BSD_SOURCE)

#if defined(_XOPEN_SOURCE) || defined(_GNU_SOURCE) || defined(_BSD_SOURCE)
#define MINSIGSTKSZ 4096
#define SIGSTKSZ    10240
#endif

#if defined(_GNU_SOURCE) || defined(_BSD_SOURCE)

typedef unsigned long greg_t, gregset_t[48];
typedef double fpregset_t[33];

typedef struct {
#ifdef __GNUC__
	__attribute__((__aligned__(16)))
#endif
	unsigned vrregs[32][4];
	struct {
#if __BIG_ENDIAN__
		unsigned _pad[3], vscr_word;
#else
		unsigned vscr_word, _pad[3];
#endif
	} vscr;
	unsigned vrsave, _pad[3];
} vrregset_t;

typedef struct sigcontext {
	unsigned long _unused[4];
	int signal;
	int _pad0;
	unsigned long handler;
	unsigned long oldmask;
	struct pt_regs *regs;
	gregset_t gp_regs;
	fpregset_t fp_regs;
	vrregset_t *v_regs;
	long vmx_reserve[34+34+32+1];
} mcontext_t;

#else

typedef struct {
	long __regs[4+4+48+33+1+34+34+32+1];
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
	sigset_t uc_sigmask;
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
#define SIGPOLL   SIGIO
#define SIGPWR    30
#define SIGSYS    31
#define SIGUNUSED SIGSYS

#define _NSIG 65