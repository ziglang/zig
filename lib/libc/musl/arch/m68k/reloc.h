#if __HAVE_68881__
#define FP_SUFFIX ""
#elif __mcffpu__
#define FP_SUFFIX "-fp64"
#else
#define FP_SUFFIX "-sf"
#endif

#define LDSO_ARCH "m68k" FP_SUFFIX

#define TPOFF_K (-0x7000)

#define REL_SYMBOLIC    R_68K_32
#define REL_OFFSET      R_68K_PC32
#define REL_GOT         R_68K_GLOB_DAT
#define REL_PLT         R_68K_JMP_SLOT
#define REL_RELATIVE    R_68K_RELATIVE
#define REL_COPY        R_68K_COPY
#define REL_DTPMOD      R_68K_TLS_DTPMOD32
#define REL_DTPOFF      R_68K_TLS_DTPREL32
#define REL_TPOFF       R_68K_TLS_TPREL32

#define CRTJMP(pc,sp) __asm__ __volatile__( \
	"move.l %1,%%sp ; jmp (%0)" : : "r"(pc), "r"(sp) : "memory" )

#define GETFUNCSYM(fp, sym, got) __asm__ ( \
	".hidden " #sym "\n" \
	"lea " #sym "-.-8,%0 \n" \
	"lea (%%pc,%0),%0 \n" \
	: "=a"(*fp) : : "memory" )
