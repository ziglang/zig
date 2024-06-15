#define __SYSCALL_LL_E(x) (x)
#define __SYSCALL_LL_O(x) (x)

#define SYSCALL_CLOBBERLIST \
	"$t0", "$t1", "$t2", "$t3", \
	"$t4", "$t5", "$t6", "$t7", "$t8", "memory"

static inline long __syscall0(long n)
{
	register long a7 __asm__("$a7") = n;
	register long a0 __asm__("$a0");

	__asm__ __volatile__ (
		"syscall 0"
		: "=r"(a0)
		: "r"(a7)
		: SYSCALL_CLOBBERLIST);
	return a0;
}

static inline long __syscall1(long n, long a)
{
	register long a7 __asm__("$a7") = n;
	register long a0 __asm__("$a0") = a;

	__asm__ __volatile__ (
		"syscall 0"
		: "+r"(a0)
		: "r"(a7)
		: SYSCALL_CLOBBERLIST);
	return a0;
}

static inline long __syscall2(long n, long a, long b)
{
	register long a7 __asm__("$a7") = n;
	register long a0 __asm__("$a0") = a;
	register long a1 __asm__("$a1") = b;

	__asm__ __volatile__ (
		"syscall 0"
		: "+r"(a0)
	        : "r"(a7), "r"(a1)
		: SYSCALL_CLOBBERLIST);
	return a0;
}

static inline long __syscall3(long n, long a, long b, long c)
{
	register long a7 __asm__("$a7") = n;
	register long a0 __asm__("$a0") = a;
	register long a1 __asm__("$a1") = b;
	register long a2 __asm__("$a2") = c;

	__asm__ __volatile__ (
		"syscall 0"
		: "+r"(a0)
	        : "r"(a7), "r"(a1), "r"(a2)
		: SYSCALL_CLOBBERLIST);
	return a0;
}

static inline long __syscall4(long n, long a, long b, long c, long d)
{
	register long a7 __asm__("$a7") = n;
	register long a0 __asm__("$a0") = a;
	register long a1 __asm__("$a1") = b;
	register long a2 __asm__("$a2") = c;
	register long a3 __asm__("$a3") = d;

	__asm__ __volatile__ (
		"syscall 0"
		: "+r"(a0)
	        : "r"(a7), "r"(a1), "r"(a2), "r"(a3)
		: SYSCALL_CLOBBERLIST);
	return a0;
}

static inline long __syscall5(long n, long a, long b, long c, long d, long e)
{
	register long a7 __asm__("$a7") = n;
	register long a0 __asm__("$a0") = a;
	register long a1 __asm__("$a1") = b;
	register long a2 __asm__("$a2") = c;
	register long a3 __asm__("$a3") = d;
	register long a4 __asm__("$a4") = e;

	__asm__ __volatile__ (
		"syscall 0"
		: "+r"(a0)
	        : "r"(a7), "r"(a1), "r"(a2), "r"(a3), "r"(a4)
		: SYSCALL_CLOBBERLIST);
	return a0;
}

static inline long __syscall6(long n, long a, long b, long c, long d, long e, long f)
{
	register long a7 __asm__("$a7") = n;
	register long a0 __asm__("$a0") = a;
	register long a1 __asm__("$a1") = b;
	register long a2 __asm__("$a2") = c;
	register long a3 __asm__("$a3") = d;
	register long a4 __asm__("$a4") = e;
	register long a5 __asm__("$a5") = f;

	__asm__ __volatile__ (
		"syscall 0"
		: "+r"(a0)
	        : "r"(a7), "r"(a1), "r"(a2), "r"(a3), "r"(a4), "r"(a5)
		: SYSCALL_CLOBBERLIST);
	return a0;
}

static inline long __syscall7(long n, long a, long b, long c, long d, long e, long f, long g)
{
	register long a7 __asm__("$a7") = n;
	register long a0 __asm__("$a0") = a;
	register long a1 __asm__("$a1") = b;
	register long a2 __asm__("$a2") = c;
	register long a3 __asm__("$a3") = d;
	register long a4 __asm__("$a4") = e;
	register long a5 __asm__("$a5") = f;
	register long a6 __asm__("$a6") = g;

	__asm__ __volatile__ (
		"syscall 0"
		: "+r"(a0)
	        : "r"(a7), "r"(a1), "r"(a2), "r"(a3), "r"(a4), "r"(a5), "r"(a6)
		: SYSCALL_CLOBBERLIST);
	return a0;
}

#define VDSO_USEFUL
#define VDSO_CGT_SYM "__vdso_clock_gettime"
#define VDSO_CGT_VER "LINUX_5.10"

#define IPC_64  0
