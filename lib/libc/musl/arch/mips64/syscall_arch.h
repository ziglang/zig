#define __SYSCALL_LL_E(x) (x)
#define __SYSCALL_LL_O(x) (x)

#define SYSCALL_RLIM_INFINITY (-1UL/2)

#if __mips_isa_rev >= 6
#define SYSCALL_CLOBBERLIST \
	"$1", "$3", "$10", "$11", "$12", "$13", \
	"$14", "$15", "$24", "$25", "memory"
#else
#define SYSCALL_CLOBBERLIST \
	"$1", "$3", "$10", "$11", "$12", "$13", \
	"$14", "$15", "$24", "$25", "hi", "lo", "memory"
#endif

static inline long __syscall0(long n)
{
	register long r7 __asm__("$7");
	register long r2 __asm__("$2") = n;
	__asm__ __volatile__ (
		"syscall"
		: "+&r"(r2), "=r"(r7)
		:
		: SYSCALL_CLOBBERLIST);
	return r7 ? -r2 : r2;
}

static inline long __syscall1(long n, long a)
{
	register long r4 __asm__("$4") = a;
	register long r7 __asm__("$7");
	register long r2 __asm__("$2") = n;
	__asm__ __volatile__ (
		"syscall"
		: "+&r"(r2), "=r"(r7)
		: "r"(r4)
		: SYSCALL_CLOBBERLIST);
	return r7 ? -r2 : r2;
}

static inline long __syscall2(long n, long a, long b)
{
	register long r4 __asm__("$4") = a;
	register long r5 __asm__("$5") = b;
	register long r7 __asm__("$7");
	register long r2 __asm__("$2") = n;

	__asm__ __volatile__ (
		"syscall"
		: "+&r"(r2), "=r"(r7)
		: "r"(r4), "r"(r5)
		: SYSCALL_CLOBBERLIST);
	return r7 ? -r2 : r2;
}

static inline long __syscall3(long n, long a, long b, long c)
{
	register long r4 __asm__("$4") = a;
	register long r5 __asm__("$5") = b;
	register long r6 __asm__("$6") = c;
	register long r7 __asm__("$7");
	register long r2 __asm__("$2") = n;

	__asm__ __volatile__ (
		"syscall"
		: "+&r"(r2), "=r"(r7)
		: "r"(r4), "r"(r5), "r"(r6)
		: SYSCALL_CLOBBERLIST);
	return r7 ? -r2 : r2;
}

static inline long __syscall4(long n, long a, long b, long c, long d)
{
	register long r4 __asm__("$4") = a;
	register long r5 __asm__("$5") = b;
	register long r6 __asm__("$6") = c;
	register long r7 __asm__("$7") = d;
	register long r2 __asm__("$2") = n;

	__asm__ __volatile__ (
		"syscall"
		: "+&r"(r2), "+r"(r7)
		: "r"(r4), "r"(r5), "r"(r6)
		: SYSCALL_CLOBBERLIST);
	return r7 ? -r2 : r2;
}

static inline long __syscall5(long n, long a, long b, long c, long d, long e)
{
	register long r4 __asm__("$4") = a;
	register long r5 __asm__("$5") = b;
	register long r6 __asm__("$6") = c;
	register long r7 __asm__("$7") = d;
	register long r8 __asm__("$8") = e;
	register long r2 __asm__("$2") = n;

	__asm__ __volatile__ (
		"syscall"
		: "+&r"(r2), "+r"(r7)
		: "r"(r4), "r"(r5), "r"(r6), "r"(r8)
		: SYSCALL_CLOBBERLIST);
	return r7 ? -r2 : r2;
}

static inline long __syscall6(long n, long a, long b, long c, long d, long e, long f)
{
	register long r4 __asm__("$4") = a;
	register long r5 __asm__("$5") = b;
	register long r6 __asm__("$6") = c;
	register long r7 __asm__("$7") = d;
	register long r8 __asm__("$8") = e;
	register long r9 __asm__("$9") = f;
	register long r2 __asm__("$2") = n;

	__asm__ __volatile__ (
		"syscall"
		: "+&r"(r2), "+r"(r7)
		: "r"(r4), "r"(r5), "r"(r6), "r"(r8), "r"(r9)
		: SYSCALL_CLOBBERLIST);
	return r7 ? -r2 : r2;
}

#define VDSO_USEFUL
#define VDSO_CGT_SYM "__vdso_clock_gettime"
#define VDSO_CGT_VER "LINUX_2.6"

#define SO_SNDTIMEO_OLD 0x1005
#define SO_RCVTIMEO_OLD 0x1006
