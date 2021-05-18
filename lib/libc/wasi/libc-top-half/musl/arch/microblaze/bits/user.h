struct user_fpregs_struct {
	long cwd, swd, twd, fip, fcs, foo, fos, st_space[20];
};

struct user_regs_struct {
	unsigned grp[32], pc, msr, ear, esr, fsr, btr, pvr[12];
};

struct user {
	struct user_regs_struct regs;
	int u_fpvalid;
	struct user_fpregs_struct elf_fpregset_t;
	unsigned long u_tsize, u_dsize, u_ssize, start_code, start_stack;
	long signal;
	int reserved;
	struct user_regs_struct *u_ar0;
	struct user_fpregs_struct *u_fpstate;
	unsigned long magic;
	char u_comm[32];
	int u_debugreg[8];
};

#define ELF_NGREG 50
typedef unsigned long elf_greg_t, elf_gregset_t[ELF_NGREG];
typedef struct user_fpregs_struct elf_fpregset_t;
