#define a_ctz_32 a_ctz_32
static inline int a_ctz_32(unsigned long x)
{
	__asm__(
		"%0 = ct0(%0)\n\t"
		: "+r"(x));
	return x;
}

#define a_ctz_64 a_ctz_64
static inline int a_ctz_64(uint64_t x)
{
	int count;
	__asm__(
		"%0 = ct0(%1)\n\t"
		: "=r"(count) : "r"(x));
	return count;
}
#define a_clz_64 a_clz_64
static inline int a_clz_64(uint64_t x)
{
        __asm__(
                "%0 = brev(%0)\n\t"
		: "+r"(x));
        return a_ctz_64(x);
}

#define a_cas a_cas
static inline int a_cas(volatile int *p, int t, int s)
{
	int dummy;
	__asm__ __volatile__(
		"1:	%0 = memw_locked(%1)\n\t"
		"	{ p0 = cmp.eq(%0, %2)\n\t"
		"	  if (!p0.new) jump:nt 2f }\n\t"
		"	memw_locked(%1, p0) = %3\n\t"
		"	if (!p0) jump 1b\n\t"
		"2:	\n\t"
		: "=&r"(dummy)
		: "r"(p), "r"(t), "r"(s)
		: "p0", "memory" );
        return dummy;
}

#define a_cas_p a_cas_p
static inline void *a_cas_p(volatile void *p, void *t, void *s)
{
	return (void *)a_cas(p, (int)t, (int)s);
}

#define a_swap a_swap
static inline int a_swap(volatile int *x, int v)
{
	int old, dummy;
	__asm__ __volatile__(
		"	%1 = %3\n\t"
		"1:	%0 = memw_locked(%2)\n\t"
		"	memw_locked(%2, p0) = %1\n\t"
		"	if (!p0) jump 1b\n\t"
		: "=&r"(old), "=&r"(dummy)
		: "r"(x), "r"(v)
		: "p0", "memory" );
        return old;
}

#define a_fetch_add a_fetch_add
static inline int a_fetch_add(volatile int *x, int v)
{
	int old, dummy;
	__asm__ __volatile__(
		"1:	%0 = memw_locked(%2)\n\t"
		"	%1 = add(%0, %3)\n\t"
		"	memw_locked(%2, p0) = %1\n\t"
		"	if (!p0) jump 1b\n\t"
		: "=&r"(old), "=&r"(dummy)
		: "r"(x), "r"(v)
		: "p0", "memory" );
        return old;
}

#define a_inc a_inc
static inline void a_inc(volatile int *x)
{
	a_fetch_add(x, 1);
}

#define a_dec a_dec
static inline void a_dec(volatile int *x)
{
	int dummy;
	__asm__ __volatile__(
		"1:	%0 = memw_locked(%1)\n\t"
		"	%0 = add(%0, #-1)\n\t"
		"	memw_locked(%1, p0) = %0\n\t"
		"	if (!p0) jump 1b\n\t"
		: "=&r"(dummy)
		: "r"(x)
		: "p0", "memory" );
}

#define a_store a_store
static inline void a_store(volatile int *p, int x)
{
	int dummy;
	__asm__ __volatile__(
		"1:	%0 = memw_locked(%1)\n\t"
		"	memw_locked(%1, p0) = %2\n\t"
		"	if (!p0) jump 1b\n\t"
		: "=&r"(dummy)
		: "r"(p), "r"(x)
		: "p0", "memory" );
}

#define a_barrier a_barrier
static inline void a_barrier()
{
	__asm__ __volatile__ ("barrier" ::: "memory");
}
#define a_spin a_spin
static inline void a_spin()
{
	__asm__ __volatile__ ("pause(#255)" :::);
}

#define a_crash a_crash
static inline void a_crash()
{
	*(volatile char *)0=0;
}

#define a_and a_and
static inline void a_and(volatile int *p, int v)
{
	int dummy;
	__asm__ __volatile__(
		"1:	%0 = memw_locked(%1)\n\t"
		"	%0 = and(%0, %2)\n\t"
		"	memw_locked(%1, p0) = %0\n\t"
		"	if (!p0) jump 1b\n\t"
		: "=&r"(dummy)
		: "r"(p), "r"(v)
		: "p0", "memory" );
}

#define  a_or a_or
static inline void a_or(volatile int *p, int v)
{
	int dummy;
	__asm__ __volatile__(
		"1:	%0 = memw_locked(%1)\n\t"
		"	%0 = or(%0, %2)\n\t"
		"	memw_locked(%1, p0) = %0\n\t"
		"	if (!p0) jump 1b\n\t"
		: "=&r"(dummy)
		: "r"(p), "r"(v)
		: "p0", "memory" );
}

#define a_or_l a_or_l
static inline void a_or_l(volatile void *p, long v)
{
	a_or(p, v);
}

#define a_and_64 a_and_64
static inline void a_and_64(volatile uint64_t *p, uint64_t v)
{
	uint64_t dummy;
	__asm__ __volatile__(
		"1:	%0 = memd_locked(%1)\n\t"
		"	%0 = and(%0, %2)\n\t"
		"	memd_locked(%1, p0) = %0\n\t"
		"	if (!p0) jump 1b\n\t"
		: "=&r"(dummy)
		: "r"(p), "r"(v)
		: "p0", "memory" );
}

#define  a_or_64 a_or_64
static inline void a_or_64(volatile uint64_t *p, uint64_t v)
{
	uint64_t dummy;
	__asm__ __volatile__(
		"1:	%0 = memd_locked(%1)\n\t"
		"	%0 = or(%0, %2)\n\t"
		"	memd_locked(%1, p0) = %0\n\t"
		"	if (!p0) jump 1b\n\t"
		: "=&r"(dummy)
		: "r"(p), "r"(v)
		: "p0", "memory" );
}
