#if defined(_SOFT_FLOAT) || defined(__NO_FPRS__)
#define FP_SUFFIX "-sf"
#else
#define FP_SUFFIX ""
#endif

#define LDSO_ARCH "powerpc" FP_SUFFIX

#define TPOFF_K (-0x7000)

#define REL_SYMBOLIC    R_PPC_ADDR32
#define REL_USYMBOLIC   R_PPC_UADDR32
#define REL_GOT         R_PPC_GLOB_DAT
#define REL_PLT         R_PPC_JMP_SLOT
#define REL_RELATIVE    R_PPC_RELATIVE
#define REL_COPY        R_PPC_COPY
#define REL_DTPMOD      R_PPC_DTPMOD32
#define REL_DTPOFF      R_PPC_DTPREL32
#define REL_TPOFF       R_PPC_TPREL32

#define CRTJMP(pc,sp) __asm__ __volatile__( \
	"mr 1,%1 ; mtlr %0 ; blr" : : "r"(pc), "r"(sp) : "memory" )

#define GETFUNCSYM(fp, sym, got) __asm__ ( \
	".hidden " #sym " \n" \
	"	bl 1f \n" \
	"	.long " #sym "-. \n" \
	"1:	mflr %1 \n" \
	"	lwz %0, 0(%1) \n" \
	"	add %0, %0, %1 \n" \
	: "=r"(*(fp)), "=r"((int){0}) : : "memory", "lr" )
