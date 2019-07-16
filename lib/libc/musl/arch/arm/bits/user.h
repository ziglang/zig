typedef struct user_fpregs {
	struct fp_reg {
		unsigned sign1:1;
		unsigned unused:15;
		unsigned sign2:1;
		unsigned exponent:14;
		unsigned j:1;
		unsigned mantissa1:31;
		unsigned mantissa0:32;
	} fpregs[8];
	unsigned fpsr:32;
	unsigned fpcr:32;
	unsigned char ftype[8];
	unsigned int init_flag;
} elf_fpregset_t;

struct user_regs {
	unsigned long uregs[18];
};
#define ELF_NGREG 18
typedef unsigned long elf_greg_t, elf_gregset_t[ELF_NGREG];

struct user {
	struct user_regs regs;
	int u_fpvalid;
	unsigned long u_tsize, u_dsize, u_ssize;
	unsigned long start_code, start_stack;
	long signal;
	int reserved;
	struct user_regs *u_ar0;
	unsigned long magic;
	char u_comm[32];
	int u_debugreg[8];
	struct user_fpregs u_fp;
	struct user_fpregs *u_fp0;
};
