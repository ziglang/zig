#define a_ll a_ll
static inline int a_ll(volatile int *p)
{
	int v;
	__asm__ __volatile__ ("lwarx %0, 0, %2" : "=r"(v) : "m"(*p), "r"(p));
	return v;
}

#define a_sc a_sc
static inline int a_sc(volatile int *p, int v)
{
	int r;
	__asm__ __volatile__ (
		"stwcx. %2, 0, %3 ; mfcr %0"
		: "=r"(r), "=m"(*p) : "r"(v), "r"(p) : "memory", "cc");
	return r & 0x20000000; /* "bit 2" of "cr0" (backwards bit order) */
}

#define a_ll_p a_ll_p
static inline void *a_ll_p(volatile void *p)
{
	void *v;
	__asm__ __volatile__ ("ldarx %0, 0, %2" : "=r"(v) : "m"(*(void *volatile *)p), "r"(p));
	return v;
}

#define a_sc_p a_sc_p
static inline int a_sc_p(volatile void *p, void *v)
{
	int r;
	__asm__ __volatile__ (
		"stdcx. %2, 0, %3 ; mfcr %0"
		: "=r"(r), "=m"(*(void *volatile *)p) : "r"(v), "r"(p) : "memory", "cc");
	return r & 0x20000000; /* "bit 2" of "cr0" (backwards bit order) */
}

#define a_barrier a_barrier
static inline void a_barrier()
{
	__asm__ __volatile__ ("sync" : : : "memory");
}

#define a_pre_llsc a_barrier

#define a_post_llsc a_post_llsc
static inline void a_post_llsc()
{
	__asm__ __volatile__ ("isync" : : : "memory");
}

#define a_crash a_crash
static inline void a_crash()
{
	__asm__ __volatile__ (".long 0");
}

#define a_clz_64 a_clz_64
static inline int a_clz_64(uint64_t x)
{
	__asm__ ("cntlzd %0, %1" : "=r"(x) : "r"(x));
	return x;
}
