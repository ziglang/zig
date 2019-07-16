#include "pthread_impl.h"
#include "libc.h"
#include <elf.h>

/* Also perform sh-specific init */

#define CPU_HAS_LLSC 0x0040
#define CPU_HAS_CAS_L 0x0400

extern hidden const char __sh_cas_gusa[], __sh_cas_llsc[], __sh_cas_imask[], __sh_cas_cas_l[];

hidden const void *__sh_cas_ptr;

hidden unsigned __sh_nommu;

int __set_thread_area(void *p)
{
	size_t *aux;
	__asm__ __volatile__ ( "ldc %0, gbr" : : "r"(p) : "memory" );
#ifndef __SH4A__
	__sh_cas_ptr = __sh_cas_gusa;
#if !defined(__SH3__) && !defined(__SH4__)
	for (aux=libc.auxv; *aux; aux+=2) {
		if (*aux != AT_PLATFORM) continue;
		const char *s = (void *)aux[1];
		if (s[0]!='s' || s[1]!='h' || s[2]!='2' || s[3]-'0'<10u) break;
		__sh_cas_ptr = __sh_cas_imask;
		__sh_nommu = 1;
	}
#endif
	if (__hwcap & CPU_HAS_CAS_L)
		__sh_cas_ptr = __sh_cas_cas_l;
	else if (__hwcap & CPU_HAS_LLSC)
		__sh_cas_ptr = __sh_cas_llsc;
#endif
	return 0;
}
