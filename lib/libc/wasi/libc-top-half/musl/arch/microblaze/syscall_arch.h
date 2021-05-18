#define __SYSCALL_LL_E(x) \
((union { long long ll; long l[2]; }){ .ll = x }).l[0], \
((union { long long ll; long l[2]; }){ .ll = x }).l[1]
#define __SYSCALL_LL_O(x) __SYSCALL_LL_E((x))

static __inline long __syscall0(long n)
{
	register unsigned long r12 __asm__("r12") = n;
	register unsigned long r3 __asm__("r3");
	__asm__ __volatile__ ("brki r14, 0x8" : "=r"(r3)
		: "r"(r12)
		: "memory", "r4");
	return r3;
}

static inline long __syscall1(long n, long a)
{
	register unsigned long r12 __asm__("r12") = n;
	register unsigned long r3 __asm__("r3");
	register unsigned long r5 __asm__("r5") = a;
	__asm__ __volatile__ ("brki r14, 0x8" : "=r"(r3)
		: "r"(r12), "r"(r5)
		: "memory", "r4");
	return r3;
}

static inline long __syscall2(long n, long a, long b)
{
	register unsigned long r12 __asm__("r12") = n;
	register unsigned long r3 __asm__("r3");
	register unsigned long r5 __asm__("r5") = a;
	register unsigned long r6 __asm__("r6") = b;
	__asm__ __volatile__ ("brki r14, 0x8" : "=r"(r3)
		: "r"(r12), "r"(r5), "r"(r6)
		: "memory", "r4");
	return r3;
}

static inline long __syscall3(long n, long a, long b, long c)
{
	register unsigned long r12 __asm__("r12") = n;
	register unsigned long r3 __asm__("r3");
	register unsigned long r5 __asm__("r5") = a;
	register unsigned long r6 __asm__("r6") = b;
	register unsigned long r7 __asm__("r7") = c;
	__asm__ __volatile__ ("brki r14, 0x8" : "=r"(r3)
		: "r"(r12), "r"(r5), "r"(r6), "r"(r7)
		: "memory", "r4");
	return r3;
}

static inline long __syscall4(long n, long a, long b, long c, long d)
{
	register unsigned long r12 __asm__("r12") = n;
	register unsigned long r3 __asm__("r3");
	register unsigned long r5 __asm__("r5") = a;
	register unsigned long r6 __asm__("r6") = b;
	register unsigned long r7 __asm__("r7") = c;
	register unsigned long r8 __asm__("r8") = d;
	__asm__ __volatile__ ("brki r14, 0x8" : "=r"(r3)
		: "r"(r12), "r"(r5), "r"(r6), "r"(r7), "r"(r8)
		: "memory", "r4");
	return r3;
}

static inline long __syscall5(long n, long a, long b, long c, long d, long e)
{
	register unsigned long r12 __asm__("r12") = n;
	register unsigned long r3 __asm__("r3");
	register unsigned long r5 __asm__("r5") = a;
	register unsigned long r6 __asm__("r6") = b;
	register unsigned long r7 __asm__("r7") = c;
	register unsigned long r8 __asm__("r8") = d;
	register unsigned long r9 __asm__("r9") = e;
	__asm__ __volatile__ ("brki r14, 0x8" : "=r"(r3)
		: "r"(r12), "r"(r5), "r"(r6), "r"(r7), "r"(r8), "r"(r9)
		: "memory", "r4");
	return r3;
}

static inline long __syscall6(long n, long a, long b, long c, long d, long e, long f)
{
	register unsigned long r12 __asm__("r12") = n;
	register unsigned long r3 __asm__("r3");
	register unsigned long r5 __asm__("r5") = a;
	register unsigned long r6 __asm__("r6") = b;
	register unsigned long r7 __asm__("r7") = c;
	register unsigned long r8 __asm__("r8") = d;
	register unsigned long r9 __asm__("r9") = e;
	register unsigned long r10 __asm__("r10") = f;
	__asm__ __volatile__ ("brki r14, 0x8" : "=r"(r3)
		: "r"(r12), "r"(r5), "r"(r6), "r"(r7), "r"(r8), "r"(r9), "r"(r10)
		: "memory", "r4");
	return r3;
}

#define SYSCALL_IPC_BROKEN_MODE

#undef SYS_socketcall
