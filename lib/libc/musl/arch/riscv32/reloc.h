#if defined __riscv_float_abi_soft
#define RISCV_FP_SUFFIX "-sf"
#elif defined __riscv_float_abi_single
#define RISCV_FP_SUFFIX "-sp"
#elif defined __riscv_float_abi_double
#define RISCV_FP_SUFFIX ""
#endif

#define LDSO_ARCH "riscv32" RISCV_FP_SUFFIX

#define TPOFF_K 0

#define REL_SYMBOLIC    R_RISCV_32
#define REL_PLT         R_RISCV_JUMP_SLOT
#define REL_RELATIVE    R_RISCV_RELATIVE
#define REL_COPY        R_RISCV_COPY
#define REL_DTPMOD      R_RISCV_TLS_DTPMOD32
#define REL_DTPOFF      R_RISCV_TLS_DTPREL32
#define REL_TPOFF       R_RISCV_TLS_TPREL32

#define CRTJMP(pc,sp) __asm__ __volatile__( \
	"mv sp, %1 ; jr %0" : : "r"(pc), "r"(sp) : "memory" )
