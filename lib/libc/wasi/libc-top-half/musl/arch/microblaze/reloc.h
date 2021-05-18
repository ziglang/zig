#if __BYTE_ORDER == __LITTLE_ENDIAN
#define ENDIAN_SUFFIX "el"
#else
#define ENDIAN_SUFFIX ""
#endif

#define LDSO_ARCH "microblaze" ENDIAN_SUFFIX

#define TPOFF_K 0

#define REL_SYMBOLIC    R_MICROBLAZE_32
#define REL_GOT         R_MICROBLAZE_GLOB_DAT
#define REL_PLT         R_MICROBLAZE_JUMP_SLOT
#define REL_RELATIVE    R_MICROBLAZE_REL
#define REL_COPY        R_MICROBLAZE_COPY
#define REL_DTPMOD      R_MICROBLAZE_TLSDTPMOD32
#define REL_DTPOFF      R_MICROBLAZE_TLSDTPREL32

#define CRTJMP(pc,sp) __asm__ __volatile__( \
	"addik r1,%1,0 ; bra %0" : : "r"(pc), "r"(sp) : "memory" )

#define GETFUNCSYM(fp, sym, got) __asm__ ( \
	".hidden " #sym " \n" \
	"	mfs %0, rpc \n" \
	"	addik %0, %0, _GLOBAL_OFFSET_TABLE_+8 \n" \
	"	addik %0, %0, " #sym "@GOTOFF \n" \
	: "=r"(*(fp)) : : "memory" )
