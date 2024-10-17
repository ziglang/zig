#define LDSO_ARCH "x32"

/* FIXME: x32 is very strange in its use of 64-bit relocation types in
 * a 32-bit environment. As long as the memory at reloc_addr is
 * zero-filled prior to relocations, just treating 64-bit relocations
 * as operating on 32-bit slots should be fine, but this should be
 * checked. In particular, R_X86_64_64, R_X86_64_DTPOFF64, and
 * R_X86_64_TPOFF64 may need checking. */

/* The R_X86_64_64, R_X86_64_DTPOFF32, and R_X86_64_TPOFF32 reloc types
 * were previously mapped in the switch table form of this file; however,
 * they do not seem to be used/usable for anything. If needed, new
 * mappings will have to be added. */

#define REL_SYMBOLIC    R_X86_64_32
#define REL_OFFSET      R_X86_64_PC32
#define REL_GOT         R_X86_64_GLOB_DAT
#define REL_PLT         R_X86_64_JUMP_SLOT
#define REL_RELATIVE    R_X86_64_RELATIVE
#define REL_COPY        R_X86_64_COPY
#define REL_DTPMOD      R_X86_64_DTPMOD64
#define REL_DTPOFF      R_X86_64_DTPOFF64
#define REL_TPOFF       R_X86_64_TPOFF64

#define CRTJMP(pc,sp) __asm__ __volatile__( \
	"mov %1,%%esp ; jmp *%0" : : "r"((uint64_t)(uintptr_t)pc), "r"(sp) : "memory" )

#define GETFUNCSYM(fp, sym, got) __asm__ ( \
	".hidden " #sym "\n" \
	"	lea " #sym "(%%rip),%0\n" \
	: "=r"(*fp) : : "memory" )
