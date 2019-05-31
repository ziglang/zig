#include "libc.h"

#if defined(__SH4A__)

#define a_ll a_ll
static inline int a_ll(volatile int *p)
{
	int v;
	__asm__ __volatile__ ("movli.l @%1, %0" : "=z"(v) : "r"(p), "m"(*p));
	return v;
}

#define a_sc a_sc
static inline int a_sc(volatile int *p, int v)
{
	int r;
	__asm__ __volatile__ (
		"movco.l %2, @%3 ; movt %0"
		: "=r"(r), "=m"(*p) : "z"(v), "r"(p) : "memory", "cc");
	return r;
}

#define a_barrier a_barrier
static inline void a_barrier()
{
	__asm__ __volatile__ ("synco" ::: "memory");
}

#define a_pre_llsc a_barrier
#define a_post_llsc a_barrier

#else

#define a_cas a_cas
extern hidden const void *__sh_cas_ptr;
static inline int a_cas(volatile int *p, int t, int s)
{
	register int r1 __asm__("r1");
	register int r2 __asm__("r2") = t;
	register int r3 __asm__("r3") = s;
	__asm__ __volatile__ (
		"jsr @%4 ; nop"
		: "=r"(r1), "+r"(r3) : "z"(p), "r"(r2), "r"(__sh_cas_ptr)
		: "memory", "pr", "cc");
	return r3;
}

#endif
