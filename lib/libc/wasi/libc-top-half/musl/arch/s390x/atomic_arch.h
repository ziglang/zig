#define a_cas a_cas
static inline int a_cas(volatile int *p, int t, int s)
{
	__asm__ __volatile__ (
		"cs %0, %2, %1"
		: "+d"(t), "+Q"(*p) : "d"(s) : "memory", "cc");
	return t;
}

#define a_cas_p a_cas_p
static inline void *a_cas_p(volatile void *p, void *t, void *s)
{
	__asm__ __volatile__ (
		"csg %0, %2, %1"
		: "+d"(t), "+Q"(*(void *volatile *)p) : "d"(s)
		: "memory", "cc");
	return t;
}

#define a_barrier a_barrier
static inline void a_barrier()
{
	__asm__ __volatile__ ("bcr 15,0" : : : "memory");
}

#define a_crash a_crash
static inline void a_crash()
{
	__asm__ __volatile__ (".insn e,0");
}
