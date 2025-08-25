#undef __WORDSIZE
#define __WORDSIZE 32

struct user_m68kfp_struct {
	unsigned long fpregs[24], fpcntl[3];
};

struct user_regs_struct {
	long d1, d2, d3, d4, d5, d6, d7;
	long a0, a1, a2, a3, a4, a5, a6;
	long d0, usp, orig_d0;
	short stkadj, sr;
	long pc;
	short fmtvec, __pad;
};

struct user {
	struct user_regs_struct regs;
	int u_fpvalid;
	struct user_m68kfp_struct m68kfp;
	unsigned long u_tsize, u_dsize, u_ssize, start_code, start_stack;
	long signal;
	int reserved;
	unsigned long u_ar0;
	struct user_m68kfp_struct *u_fpstate;
	unsigned long magic;
	char u_comm[32];
};

#define ELF_NGREG 20
typedef unsigned long elf_greg_t;
typedef elf_greg_t elf_gregset_t[ELF_NGREG];
typedef struct user_m68kfp_struct elf_fpregset_t;

#define NBPG			4096
#define UPAGES			1
#define HOST_TEXT_START_ADDR	(u.start_code)
#define HOST_STACK_END_ADDR	(u.start_stack + u.u_ssize * NBPG)
