#define LDSO_ARCH "or1k"

#define TPOFF_K 0

#define REL_SYMBOLIC    R_OR1K_32
#define REL_GOT         R_OR1K_GLOB_DAT
#define REL_PLT         R_OR1K_JMP_SLOT
#define REL_RELATIVE    R_OR1K_RELATIVE
#define REL_COPY        R_OR1K_COPY
#define REL_DTPMOD      R_OR1K_TLS_DTPMOD
#define REL_DTPOFF      R_OR1K_TLS_DTPOFF
#define REL_TPOFF       R_OR1K_TLS_TPOFF

#define CRTJMP(pc,sp) __asm__ __volatile__( \
	"l.jr %0 ; l.ori r1,%1,0" : : "r"(pc), "r"(sp) : "memory" )

#define GETFUNCSYM(fp, sym, got) __asm__ ( \
	".hidden " #sym " \n" \
	"	l.jal 1f \n" \
	"	 l.nop \n" \
	"	.word " #sym "-. \n" \
	"1:	l.lwz %0, 0(r9) \n" \
	"	l.add %0, %0, r9 \n" \
	: "=r"(*(fp)) : : "memory", "r9" )
