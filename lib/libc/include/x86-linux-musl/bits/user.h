#undef __WORDSIZE
#define __WORDSIZE 32

typedef struct user_fpregs_struct {
	long cwd, swd, twd, fip, fcs, foo, fos, st_space[20];
} elf_fpregset_t;

typedef struct user_fpxregs_struct {
	unsigned short cwd, swd, twd, fop;
	long fip, fcs, foo, fos, mxcsr, reserved;
	long st_space[32], xmm_space[32], padding[56];
} elf_fpxregset_t;

struct user_regs_struct {
	long ebx, ecx, edx, esi, edi, ebp, eax, xds, xes, xfs, xgs;
	long orig_eax, eip, xcs, eflags, esp, xss;
};

#define ELF_NGREG 17
typedef unsigned long elf_greg_t, elf_gregset_t[ELF_NGREG];

struct user {
	struct user_regs_struct		regs;
	int				u_fpvalid;
	struct user_fpregs_struct	i387;
	unsigned long			u_tsize;
	unsigned long			u_dsize;
	unsigned long			u_ssize;
	unsigned long			start_code;
	unsigned long			start_stack;
	long				signal;
	int				reserved;
	struct user_regs_struct		*u_ar0;
	struct user_fpregs_struct	*u_fpstate;
	unsigned long			magic;
	char				u_comm[32];
	int				u_debugreg[8];
};

#define PAGE_MASK		(~(PAGESIZE-1))
#define NBPG			PAGESIZE
#define UPAGES			1
#define HOST_TEXT_START_ADDR	(u.start_code)
#define HOST_STACK_END_ADDR	(u.start_stack + u.u_ssize * NBPG)