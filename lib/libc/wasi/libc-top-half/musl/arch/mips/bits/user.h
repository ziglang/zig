struct user {
	unsigned long regs[45+64];
	unsigned long u_tsize, u_dsize, u_ssize;
	unsigned long start_code, start_data, start_stack;
	long signal;
	void *u_ar0;
	unsigned long magic;
	char u_comm[32];
};
#define ELF_NGREG 45
#define ELF_NFPREG 33
typedef unsigned long elf_greg_t, elf_gregset_t[ELF_NGREG];
typedef double elf_fpreg_t, elf_fpregset_t[ELF_NFPREG];
