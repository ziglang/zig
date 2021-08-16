#if defined(_POSIX_SOURCE) || defined(_POSIX_C_SOURCE) \
 || defined(_XOPEN_SOURCE) || defined(_GNU_SOURCE) || defined(_BSD_SOURCE)

#if defined(_XOPEN_SOURCE) || defined(_GNU_SOURCE) || defined(_BSD_SOURCE)
#define MINSIGSTKSZ 2048
#define SIGSTKSZ 8192
#endif

#ifdef _GNU_SOURCE
enum { R_D0 = 0 };
#define R_D0 R_D0
enum { R_D1 = 1 };
#define R_D1 R_D1
enum { R_D2 = 2 };
#define R_D2 R_D2
enum { R_D3 = 3 };
#define R_D3 R_D3
enum { R_D4 = 4 };
#define R_D4 R_D4
enum { R_D5 = 5 };
#define R_D5 R_D5
enum { R_D6 = 6 };
#define R_D6 R_D6
enum { R_D7 = 7 };
#define R_D7 R_D7
enum { R_A0 = 8 };
#define R_A0 R_A0
enum { R_A1 = 9 };
#define R_A1 R_A1
enum { R_A2 = 10 };
#define R_A2 R_A2
enum { R_A3 = 11 };
#define R_A3 R_A3
enum { R_A4 = 12 };
#define R_A4 R_A4
enum { R_A5 = 13 };
#define R_A5 R_A5
enum { R_A6 = 14 };
#define R_A6 R_A6
enum { R_A7 = 15 };
#define R_A7 R_A7
enum { R_SP = 15 };
#define R_SP R_SP
enum { R_PC = 16 };
#define R_PC R_PC
enum { R_PS = 17 };
#define R_PS R_PS
#endif

#if defined(_GNU_SOURCE) || defined(_BSD_SOURCE)

struct sigcontext {
	unsigned long sc_mask, sc_usp, sc_d0, sc_d1, sc_a0, sc_a1;
	unsigned short sc_sr;
	unsigned long sc_pc;
	unsigned short sc_formatvec;
	unsigned long sc_fpregs[6], sc_fpcntl[3];
	unsigned char sc_fpstate[216];
};

typedef int greg_t, gregset_t[18];
typedef struct {
	int f_pcr, f_psr, f_fpiaddr, f_fpregs[8][3];
} fpregset_t;

typedef struct {
	int version;
	gregset_t gregs;
	fpregset_t fpregs;
} mcontext_t;
#else
typedef struct {
	int __version;
	int __gregs[18];
	int __fpregs[27];
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
	mcontext_t uc_mcontext;
	long __reserved[80];
	sigset_t uc_sigmask;
} ucontext_t;

#define SA_NOCLDSTOP  1
#define SA_NOCLDWAIT  2
#define SA_SIGINFO    4
#define SA_ONSTACK    0x08000000
#define SA_RESTART    0x10000000
#define SA_NODEFER    0x40000000
#define SA_RESETHAND  0x80000000
#define SA_RESTORER   0x04000000

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