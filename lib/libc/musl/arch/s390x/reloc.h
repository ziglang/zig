#define LDSO_ARCH "s390x"

#define REL_SYMBOLIC    R_390_64
#define REL_GOT         R_390_GLOB_DAT
#define REL_PLT         R_390_JMP_SLOT
#define REL_RELATIVE    R_390_RELATIVE
#define REL_COPY        R_390_COPY
#define REL_DTPMOD      R_390_TLS_DTPMOD
#define REL_DTPOFF      R_390_TLS_DTPOFF
#define REL_TPOFF       R_390_TLS_TPOFF

#define CRTJMP(pc,sp) __asm__ __volatile__( \
	"lgr %%r15,%1; br %0" : : "r"(pc), "r"(sp) : "memory" )
