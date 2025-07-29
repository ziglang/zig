#include <endian.h>

#define LDSO_ARCH "hexagon"
#define TPOFF_K 0

#define REL_SYMBOLIC    R_HEX_32
#define REL_GOT         R_HEX_GLOB_DAT
#define REL_PLT         R_HEX_JMP_SLOT
#define REL_RELATIVE    R_HEX_RELATIVE
#define REL_COPY        R_HEX_COPY
#define REL_DTPMOD      R_HEX_DTPMOD_32
#define REL_TPOFF       R_HEX_TPREL_32
#define REL_DTPOFF      R_HEX_DTPREL_32

#define CRTJMP(pc,sp) __asm__ __volatile__( \
	"r29 = %1 ; jumpr %0" : : "r"(pc), "r"(sp) : "memory" )
