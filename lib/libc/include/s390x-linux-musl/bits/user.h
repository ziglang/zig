#undef __WORDSIZE
#define __WORDSIZE 64

typedef union {
	double d;
	float f;
} elf_fpreg_t;

typedef struct {
	unsigned fpc;
	elf_fpreg_t fprs[16];
} elf_fpregset_t;

#define ELF_NGREG 27
typedef unsigned long elf_greg_t, elf_gregset_t[ELF_NGREG];

struct _user_psw_struct {
	unsigned long mask, addr;
};

struct _user_fpregs_struct {
	unsigned fpc;
	double fprs[16];
};

struct _user_per_struct {
	unsigned long control_regs[3];
	unsigned single_step       : 1;
	unsigned instruction_fetch : 1;
	unsigned                   : 30;
	unsigned long starting_addr, ending_addr;
	unsigned short perc_atmid;
	unsigned long address;
	unsigned char access_id;
};

struct _user_regs_struct {
	struct _user_psw_struct psw;
	unsigned long gprs[16];
	unsigned acrs[16];
	unsigned long orig_gpr2;
	struct _user_fpregs_struct fp_regs;
	struct _user_per_struct per_info;
	unsigned long ieee_instruction_pointer;
};

struct user {
	struct _user_regs_struct regs;
	unsigned long u_tsize, u_dsize, u_ssize;
	unsigned long start_code, start_stack;
	long signal;
	struct _user_regs_struct *u_ar0;
	unsigned long magic;
	char u_comm[32];
};

#define PAGE_MASK            (~(PAGESIZE-1))
#define NBPG                 PAGESIZE
#define UPAGES               1
#define HOST_TEXT_START_ADDR (u.start_code)
#define HOST_STACK_END_ADDR  (u.start_stack + u.u_ssize * NBPG)