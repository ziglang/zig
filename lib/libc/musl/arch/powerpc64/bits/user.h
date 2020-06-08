struct user {
	struct {
		unsigned long gpr[32], nip, msr, orig_gpr3, ctr, link, xer, ccr, softe;
		unsigned long trap, dar, dsisr, result;
	} regs;
	unsigned long u_tsize, u_dsize, u_ssize;
	unsigned long start_code, start_data, start_stack;
	long signal;
	void *u_ar0;
	unsigned long magic;
	char u_comm[32];
};

#define ELF_NGREG 48
#define ELF_NFPREG 33
#define ELF_NVRREG 34
typedef unsigned long elf_greg_t, elf_gregset_t[ELF_NGREG];
typedef double elf_fpreg_t, elf_fpregset_t[ELF_NFPREG];
typedef struct { unsigned u[4]; }
#ifdef __GNUC__
__attribute__((__aligned__(16)))
#endif
	elf_vrreg_t, elf_vrregset_t[ELF_NVRREG];
