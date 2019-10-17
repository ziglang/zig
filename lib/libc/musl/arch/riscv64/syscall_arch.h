#define __SYSCALL_LL_E(x) (x)
#define __SYSCALL_LL_O(x) (x)

#define __asm_syscall(...) \
	__asm__ __volatile__ ("ecall\n\t" \
	: "=r"(a0) : __VA_ARGS__ : "memory"); \
	return a0; \

static inline long __syscall0(long n)
{
	register long a7 __asm__("a7") = n;
	register long a0 __asm__("a0");
	__asm_syscall("r"(a7))
}

static inline long __syscall1(long n, long a)
{
	register long a7 __asm__("a7") = n;
	register long a0 __asm__("a0") = a;
	__asm_syscall("r"(a7), "0"(a0))
}

static inline long __syscall2(long n, long a, long b)
{
	register long a7 __asm__("a7") = n;
	register long a0 __asm__("a0") = a;
	register long a1 __asm__("a1") = b;
	__asm_syscall("r"(a7), "0"(a0), "r"(a1))
}

static inline long __syscall3(long n, long a, long b, long c)
{
	register long a7 __asm__("a7") = n;
	register long a0 __asm__("a0") = a;
	register long a1 __asm__("a1") = b;
	register long a2 __asm__("a2") = c;
	__asm_syscall("r"(a7), "0"(a0), "r"(a1), "r"(a2))
}

static inline long __syscall4(long n, long a, long b, long c, long d)
{
	register long a7 __asm__("a7") = n;
	register long a0 __asm__("a0") = a;
	register long a1 __asm__("a1") = b;
	register long a2 __asm__("a2") = c;
	register long a3 __asm__("a3") = d;
	__asm_syscall("r"(a7), "0"(a0), "r"(a1), "r"(a2), "r"(a3))
}

static inline long __syscall5(long n, long a, long b, long c, long d, long e)
{
	register long a7 __asm__("a7") = n;
	register long a0 __asm__("a0") = a;
	register long a1 __asm__("a1") = b;
	register long a2 __asm__("a2") = c;
	register long a3 __asm__("a3") = d;
	register long a4 __asm__("a4") = e;
	__asm_syscall("r"(a7), "0"(a0), "r"(a1), "r"(a2), "r"(a3), "r"(a4))
}

static inline long __syscall6(long n, long a, long b, long c, long d, long e, long f)
{
	register long a7 __asm__("a7") = n;
	register long a0 __asm__("a0") = a;
	register long a1 __asm__("a1") = b;
	register long a2 __asm__("a2") = c;
	register long a3 __asm__("a3") = d;
	register long a4 __asm__("a4") = e;
	register long a5 __asm__("a5") = f;
	__asm_syscall("r"(a7), "0"(a0), "r"(a1), "r"(a2), "r"(a3), "r"(a4), "r"(a5))
}

#define VDSO_USEFUL
/* We don't have a clock_gettime function.
#define VDSO_CGT_SYM "__vdso_clock_gettime"
#define VDSO_CGT_VER "LINUX_2.6" */

#define IPC_64 0
