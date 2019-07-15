#define LDSO_ARCH "i386"

#define REL_SYMBOLIC    R_386_32
#define REL_OFFSET      R_386_PC32
#define REL_GOT         R_386_GLOB_DAT
#define REL_PLT         R_386_JMP_SLOT
#define REL_RELATIVE    R_386_RELATIVE
#define REL_COPY        R_386_COPY
#define REL_DTPMOD      R_386_TLS_DTPMOD32
#define REL_DTPOFF      R_386_TLS_DTPOFF32
#define REL_TPOFF       R_386_TLS_TPOFF
#define REL_TPOFF_NEG   R_386_TLS_TPOFF32
#define REL_TLSDESC     R_386_TLS_DESC

#define CRTJMP(pc,sp) __asm__ __volatile__( \
	"mov %1,%%esp ; jmp *%0" : : "r"(pc), "r"(sp) : "memory" )

#define GETFUNCSYM(fp, sym, got) __asm__ ( \
	".hidden " #sym "\n" \
	"	call 1f\n" \
	"1:	addl $" #sym "-.,(%%esp)\n" \
	"	pop %0" \
	: "=r"(*fp) : : "memory" )
