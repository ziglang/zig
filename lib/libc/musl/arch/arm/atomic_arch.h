#include "libc.h"

#if __ARM_ARCH_4__ || __ARM_ARCH_4T__ || __ARM_ARCH == 4
#define BLX "mov lr,pc\n\tbx"
#else
#define BLX "blx"
#endif

extern hidden uintptr_t __a_cas_ptr, __a_barrier_ptr;

#if ((__ARM_ARCH_6__ || __ARM_ARCH_6K__ || __ARM_ARCH_6KZ__ || __ARM_ARCH_6ZK__) && !__thumb__) \
 || __ARM_ARCH_6T2__ || __ARM_ARCH_7A__ || __ARM_ARCH_7R__ || __ARM_ARCH >= 7

#define a_ll a_ll
static inline int a_ll(volatile int *p)
{
	int v;
	__asm__ __volatile__ ("ldrex %0, %1" : "=r"(v) : "Q"(*p));
	return v;
}

#define a_sc a_sc
static inline int a_sc(volatile int *p, int v)
{
	int r;
	__asm__ __volatile__ ("strex %0,%2,%1" : "=&r"(r), "=Q"(*p) : "r"(v) : "memory");
	return !r;
}

#if __ARM_ARCH_7A__ || __ARM_ARCH_7R__ ||  __ARM_ARCH >= 7

#define a_barrier a_barrier
static inline void a_barrier()
{
	__asm__ __volatile__ ("dmb ish" : : : "memory");
}

#endif

#define a_pre_llsc a_barrier
#define a_post_llsc a_barrier

#else

#define a_cas a_cas
static inline int a_cas(volatile int *p, int t, int s)
{
	for (;;) {
		register int r0 __asm__("r0") = t;
		register int r1 __asm__("r1") = s;
		register volatile int *r2 __asm__("r2") = p;
		register uintptr_t r3 __asm__("r3") = __a_cas_ptr;
		int old;
		__asm__ __volatile__ (
			BLX " r3"
			: "+r"(r0), "+r"(r3) : "r"(r1), "r"(r2)
			: "memory", "lr", "ip", "cc" );
		if (!r0) return t;
		if ((old=*p)!=t) return old;
	}
}

#endif

#ifndef a_barrier
#define a_barrier a_barrier
static inline void a_barrier()
{
	register uintptr_t ip __asm__("ip") = __a_barrier_ptr;
	__asm__ __volatile__( BLX " ip" : "+r"(ip) : : "memory", "cc", "lr" );
}
#endif

#define a_crash a_crash
static inline void a_crash()
{
	__asm__ __volatile__(
#ifndef __thumb__
		".word 0xe7f000f0"
#else
		".short 0xdeff"
#endif
		: : : "memory");
}

#if __ARM_ARCH >= 5 && (!__thumb__ || __thumb2__)

#define a_clz_32 a_clz_32
static inline int a_clz_32(uint32_t x)
{
	__asm__ ("clz %0, %1" : "=r"(x) : "r"(x));
	return x;
}

#if __ARM_ARCH_6T2__ || __ARM_ARCH_7A__ || __ARM_ARCH_7R__ || __ARM_ARCH >= 7

#define a_ctz_32 a_ctz_32
static inline int a_ctz_32(uint32_t x)
{
	uint32_t xr;
	__asm__ ("rbit %0, %1" : "=r"(xr) : "r"(x));
	return a_clz_32(xr);
}

#endif

#endif
