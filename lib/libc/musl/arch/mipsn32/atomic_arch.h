#if __mips_isa_rev < 6
#define LLSC_M "m"
#else
#define LLSC_M "ZC"
#endif

#define a_ll a_ll
static inline int a_ll(volatile int *p)
{
	int v;
#if __mips < 2
	__asm__ __volatile__ (
		".set push ; .set mips2\n\t"
		"ll %0, %1"
		"\n\t.set pop"
		: "=r"(v) : "m"(*p));
#else
	__asm__ __volatile__ (
		"ll %0, %1"
		: "=r"(v) : LLSC_M(*p));
#endif
	return v;
}

#define a_sc a_sc
static inline int a_sc(volatile int *p, int v)
{
	int r;
#if __mips < 2
	__asm__ __volatile__ (
		".set push ; .set mips2\n\t"
		"sc %0, %1"
		"\n\t.set pop"
		: "=r"(r), "=m"(*p) : "0"(v) : "memory");
#else
	__asm__ __volatile__ (
		"sc %0, %1"
		: "=r"(r), "="LLSC_M(*p) : "0"(v) : "memory");
#endif
	return r;
}

#define a_barrier a_barrier
static inline void a_barrier()
{
	__asm__ __volatile__ ("sync" : : : "memory");
}

#define a_pre_llsc a_barrier
#define a_post_llsc a_barrier

#undef LLSC_M
