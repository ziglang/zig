#if __BYTE_ORDER == __LITTLE_ENDIAN
#define ENDIAN_SUFFIX "le"
#else
#define ENDIAN_SUFFIX ""
#endif

#define LDSO_ARCH "powerpc64" ENDIAN_SUFFIX

#define TPOFF_K (-0x7000)

#define REL_SYMBOLIC    R_PPC64_ADDR64
#define REL_USYMBOLIC   R_PPC64_UADDR64
#define REL_GOT         R_PPC64_GLOB_DAT
#define REL_PLT         R_PPC64_JMP_SLOT
#define REL_RELATIVE    R_PPC64_RELATIVE
#define REL_COPY        R_PPC64_COPY
#define REL_DTPMOD      R_PPC64_DTPMOD64
#define REL_DTPOFF      R_PPC64_DTPREL64
#define REL_TPOFF       R_PPC64_TPREL64

#define CRTJMP(pc,sp) __asm__ __volatile__( \
	"mr 1,%1; mr 12,%0; mtctr 12; bctrl" : : "r"(pc), "r"(sp) : "memory" )

#define GETFUNCSYM(fp, sym, got) __asm__ ( \
	".hidden " #sym " \n" \
	"	bl 1f \n" \
	"	.long " #sym "-. \n" \
	"1:	mflr %1 \n" \
	"	lwa %0, 0(%1) \n" \
	"	add %0, %0, %1 \n" \
	: "=r"(*(fp)), "=r"((long){0}) : : "memory", "lr" )
