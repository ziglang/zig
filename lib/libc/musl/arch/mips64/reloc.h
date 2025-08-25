#if __mips_isa_rev >= 6
#define ISA_SUFFIX "r6"
#else
#define ISA_SUFFIX ""
#endif

#if __BYTE_ORDER == __LITTLE_ENDIAN
#define ENDIAN_SUFFIX "el"
#else
#define ENDIAN_SUFFIX ""
#endif

#ifdef __mips_soft_float
#define FP_SUFFIX "-sf"
#else
#define FP_SUFFIX ""
#endif

#define LDSO_ARCH "mips64" ISA_SUFFIX ENDIAN_SUFFIX FP_SUFFIX

#define TPOFF_K (-0x7000)

#define REL_SYM_OR_REL  4611
#define REL_PLT         R_MIPS_JUMP_SLOT
#define REL_COPY        R_MIPS_COPY
#define REL_DTPMOD      R_MIPS_TLS_DTPMOD64
#define REL_DTPOFF      R_MIPS_TLS_DTPREL64
#define REL_TPOFF       R_MIPS_TLS_TPREL64

#include <endian.h>

#undef R_TYPE
#undef R_SYM
#undef R_INFO
#define R_TYPE(x) (be64toh(x)&0x7fffffff)
#define R_SYM(x) (be32toh(be64toh(x)>>32))
#define R_INFO(s,t) (htobe64((uint64_t)htobe32(s)<<32 | (uint64_t)t))

#define NEED_MIPS_GOT_RELOCS 1
#define DT_DEBUG_INDIRECT DT_MIPS_RLD_MAP
#define DT_DEBUG_INDIRECT_REL DT_MIPS_RLD_MAP_REL
#define ARCH_SYM_REJECT_UND(s) (!((s)->st_other & STO_MIPS_PLT))

#define CRTJMP(pc,sp) __asm__ __volatile__( \
	"move $sp,%1 ; jr %0" : : "r"(pc), "r"(sp) : "memory" )

#define GETFUNCSYM(fp, sym, got) __asm__ ( \
	".hidden " #sym "\n" \
	".set push \n" \
	".set noreorder \n" \
	".align 8 \n" \
	"	bal 1f \n" \
	"	 nop \n" \
	"	.gpdword . \n" \
	"	.gpdword " #sym " \n" \
	"1:	ld %0, ($ra) \n" \
	"	dsubu %0, $ra, %0 \n" \
	"	ld $ra, 8($ra) \n" \
	"	daddu %0, %0, $ra \n" \
	".set pop \n" \
	: "=r"(*(fp)) : : "memory", "ra" )
