#define __SYSCALL_LL_E(x) \
((union { long long ll; long l[2]; }){ .ll = x }).l[0], \
((union { long long ll; long l[2]; }){ .ll = x }).l[1]
#define __SYSCALL_LL_O(x) __SYSCALL_LL_E((x))

static __inline long __syscall0(long n)
{
	register unsigned long d0 __asm__("d0") = n;
	__asm__ __volatile__ ("trap #0" : "+r"(d0)
		:
		: "memory");
	return d0;
}

static inline long __syscall1(long n, long a)
{
	register unsigned long d0 __asm__("d0") = n;
	register unsigned long d1 __asm__("d1") = a;
	__asm__ __volatile__ ("trap #0" : "+r"(d0)
		: "r"(d1)
		: "memory");
	return d0;
}

static inline long __syscall2(long n, long a, long b)
{
	register unsigned long d0 __asm__("d0") = n;
	register unsigned long d1 __asm__("d1") = a;
	register unsigned long d2 __asm__("d2") = b;
	__asm__ __volatile__ ("trap #0" : "+r"(d0)
		: "r"(d1), "r"(d2)
		: "memory");
	return d0;
}

static inline long __syscall3(long n, long a, long b, long c)
{
	register unsigned long d0 __asm__("d0") = n;
	register unsigned long d1 __asm__("d1") = a;
	register unsigned long d2 __asm__("d2") = b;
	register unsigned long d3 __asm__("d3") = c;
	__asm__ __volatile__ ("trap #0" : "+r"(d0)
		: "r"(d1), "r"(d2), "r"(d3)
		: "memory");
	return d0;
}

static inline long __syscall4(long n, long a, long b, long c, long d)
{
	register unsigned long d0 __asm__("d0") = n;
	register unsigned long d1 __asm__("d1") = a;
	register unsigned long d2 __asm__("d2") = b;
	register unsigned long d3 __asm__("d3") = c;
	register unsigned long d4 __asm__("d4") = d;
	__asm__ __volatile__ ("trap #0" : "+r"(d0)
		: "r"(d1), "r"(d2), "r"(d3), "r"(d4)
		: "memory");
	return d0;
}

static inline long __syscall5(long n, long a, long b, long c, long d, long e)
{
	register unsigned long d0 __asm__("d0") = n;
	register unsigned long d1 __asm__("d1") = a;
	register unsigned long d2 __asm__("d2") = b;
	register unsigned long d3 __asm__("d3") = c;
	register unsigned long d4 __asm__("d4") = d;
	register unsigned long d5 __asm__("d5") = e;
	__asm__ __volatile__ ("trap #0" : "+r"(d0)
		: "r"(d1), "r"(d2), "r"(d3), "r"(d4), "r"(d5)
		: "memory");
	return d0;
}

static inline long __syscall6(long n, long a, long b, long c, long d, long e, long f)
{
	register unsigned long d0 __asm__("d0") = n;
	register unsigned long d1 __asm__("d1") = a;
	register unsigned long d2 __asm__("d2") = b;
	register unsigned long d3 __asm__("d3") = c;
	register unsigned long d4 __asm__("d4") = d;
	register unsigned long d5 __asm__("d5") = e;
	register unsigned long a0 __asm__("a0") = f;
	__asm__ __volatile__ ("trap #0" : "+r"(d0)
		: "r"(d1), "r"(d2), "r"(d3), "r"(d4), "r"(d5), "r"(a0)
		: "memory");
	return d0;
}

#define SYSCALL_IPC_BROKEN_MODE
