#define __SYSCALL_LL_E(x) \
((union { long long ll; long l[2]; }){ .ll = x }).l[0], \
((union { long long ll; long l[2]; }){ .ll = x }).l[1]
#define __SYSCALL_LL_O(x) __SYSCALL_LL_E((x))
#define __SYSCALL_LL_PRW(x) 0, __SYSCALL_LL_E((x))

/* The extra OR instructions are to work around a hardware bug:
 * http://documentation.renesas.com/doc/products/mpumcu/tu/tnsh7456ae.pdf
 */
#define __asm_syscall(trapno, ...) do {   \
	__asm__ __volatile__ (                \
		"trapa #31\n"            \
		"or r0, r0\n"                     \
		"or r0, r0\n"                     \
		"or r0, r0\n"                     \
		"or r0, r0\n"                     \
		"or r0, r0\n"                     \
	: "=r"(r0) : __VA_ARGS__ : "memory"); \
	return r0;                            \
	} while (0)

static inline long __syscall0(long n)
{
	register long r3 __asm__("r3") = n;
	register long r0 __asm__("r0");
	__asm_syscall(16, "r"(r3));
}

static inline long __syscall1(long n, long a)
{
	register long r3 __asm__("r3") = n;
	register long r4 __asm__("r4") = a;
	register long r0 __asm__("r0");
	__asm_syscall(17, "r"(r3), "r"(r4));
}

static inline long __syscall2(long n, long a, long b)
{
	register long r3 __asm__("r3") = n;
	register long r4 __asm__("r4") = a;
	register long r5 __asm__("r5") = b;
	register long r0 __asm__("r0");
	__asm_syscall(18, "r"(r3), "r"(r4), "r"(r5));
}

static inline long __syscall3(long n, long a, long b, long c)
{
	register long r3 __asm__("r3") = n;
	register long r4 __asm__("r4") = a;
	register long r5 __asm__("r5") = b;
	register long r6 __asm__("r6") = c;
	register long r0 __asm__("r0");
	__asm_syscall(19, "r"(r3), "r"(r4), "r"(r5), "r"(r6));
}

static inline long __syscall4(long n, long a, long b, long c, long d)
{
	register long r3 __asm__("r3") = n;
	register long r4 __asm__("r4") = a;
	register long r5 __asm__("r5") = b;
	register long r6 __asm__("r6") = c;
	register long r7 __asm__("r7") = d;
	register long r0 __asm__("r0");
	__asm_syscall(20, "r"(r3), "r"(r4), "r"(r5), "r"(r6), "r"(r7));
}

static inline long __syscall5(long n, long a, long b, long c, long d, long e)
{
	register long r3 __asm__("r3") = n;
	register long r4 __asm__("r4") = a;
	register long r5 __asm__("r5") = b;
	register long r6 __asm__("r6") = c;
	register long r7 __asm__("r7") = d;
	register long r0 __asm__("r0") = e;
	__asm_syscall(21, "r"(r3), "r"(r4), "r"(r5), "r"(r6), "r"(r7), "0"(r0));
}

static inline long __syscall6(long n, long a, long b, long c, long d, long e, long f)
{
	register long r3 __asm__("r3") = n;
	register long r4 __asm__("r4") = a;
	register long r5 __asm__("r5") = b;
	register long r6 __asm__("r6") = c;
	register long r7 __asm__("r7") = d;
	register long r0 __asm__("r0") = e;
	register long r1 __asm__("r1") = f;
	__asm_syscall(22, "r"(r3), "r"(r4), "r"(r5), "r"(r6), "r"(r7), "0"(r0), "r"(r1));
}

#define SYSCALL_IPC_BROKEN_MODE

#define SIOCGSTAMP_OLD   (2U<<30 | 's'<<8 | 100 | 8<<16)
#define SIOCGSTAMPNS_OLD (2U<<30 | 's'<<8 | 101 | 8<<16)
