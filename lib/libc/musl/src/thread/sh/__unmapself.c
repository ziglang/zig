#include "pthread_impl.h"

hidden void __unmapself_sh_mmu(void *, size_t);
hidden void __unmapself_sh_nommu(void *, size_t);

#if !defined(__SH3__) && !defined(__SH4__)
#define __unmapself __unmapself_sh_nommu
#include "dynlink.h"
#undef CRTJMP
#define CRTJMP(pc,sp) __asm__ __volatile__( \
	"mov.l @%0+,r0 ; mov.l @%0,r12 ; jmp @r0 ; mov %1,r15" \
	: : "r"(pc), "r"(sp) : "r0", "memory" )
#include "../__unmapself.c"
#undef __unmapself
extern hidden unsigned __sh_nommu;
#else
#define __sh_nommu 0
#endif

void __unmapself(void *base, size_t size)
{
	if (__sh_nommu) __unmapself_sh_nommu(base, size);
	else __unmapself_sh_mmu(base, size);
}
