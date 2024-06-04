#include <signal.h>

#define ELF_NGREG 32
#define ELF_NFPREG 33
typedef unsigned long elf_greg_t, elf_gregset_t[ELF_NGREG];
typedef union __riscv_mc_fp_state elf_fpregset_t;
