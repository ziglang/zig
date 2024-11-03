struct user {
	unsigned long regs[102];
	unsigned long u_tsize, u_dsize, u_ssize;
	unsigned long long start_code, start_data, start_stack;
	long long signal;
	unsigned long long *u_ar0;
	unsigned long long magic;
	char u_comm[32];
};

#define ELF_NGREG 45
#define ELF_NFPREG 33

typedef unsigned long elf_greg_t, elf_gregset_t[ELF_NGREG];
typedef double elf_fpreg_t, elf_fpregset_t[ELF_NFPREG];