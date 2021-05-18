#define a_cas a_cas
static inline int a_cas(volatile int *p, int t, int s)
{
	register int old, tmp;
	__asm__ __volatile__ (
		"	addi %0, r0, 0\n"
		"1:	lwx %0, %2, r0\n"
		"	rsubk %1, %0, %3\n"
		"	bnei %1, 1f\n"
		"	swx %4, %2, r0\n"
		"	addic %1, r0, 0\n"
		"	bnei %1, 1b\n"
		"1:	"
		: "=&r"(old), "=&r"(tmp)
		: "r"(p), "r"(t), "r"(s)
		: "cc", "memory" );
	return old;
}

#define a_swap a_swap
static inline int a_swap(volatile int *x, int v)
{
	register int old, tmp;
	__asm__ __volatile__ (
		"	addi %0, r0, 0\n"
		"1:	lwx %0, %2, r0\n"
		"	swx %3, %2, r0\n"
		"	addic %1, r0, 0\n"
		"	bnei %1, 1b\n"
		"1:	"
		: "=&r"(old), "=&r"(tmp)
		: "r"(x), "r"(v)
		: "cc", "memory" );
	return old;
}

#define a_fetch_add a_fetch_add
static inline int a_fetch_add(volatile int *x, int v)
{
	register int new, tmp;
	__asm__ __volatile__ (
		"	addi %0, r0, 0\n"
		"1:	lwx %0, %2, r0\n"
		"	addk %0, %0, %3\n"
		"	swx %0, %2, r0\n"
		"	addic %1, r0, 0\n"
		"	bnei %1, 1b\n"
		"1:	"
		: "=&r"(new), "=&r"(tmp)
		: "r"(x), "r"(v)
		: "cc", "memory" );
	return new-v;
}
