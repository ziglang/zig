#define __SYSCALL_LL_E(x) (x)
#define __SYSCALL_LL_O(x) (x)

#define __asm_syscall(ret, ...) do { \
	__asm__ __volatile__ ("svc 0\n" \
	: ret : __VA_ARGS__ : "memory"); \
	return r2; \
	} while (0)

static inline long __syscall0(long n)
{
	register long r1 __asm__("r1") = n;
	register long r2 __asm__("r2");
	__asm_syscall("=r"(r2), "r"(r1));
}

static inline long __syscall1(long n, long a)
{
	register long r1 __asm__("r1") = n;
	register long r2 __asm__("r2") = a;
	__asm_syscall("+r"(r2), "r"(r1));
}

static inline long __syscall2(long n, long a, long b)
{
	register long r1 __asm__("r1") = n;
	register long r2 __asm__("r2") = a;
	register long r3 __asm__("r3") = b;
	__asm_syscall("+r"(r2), "r"(r1), "r"(r3));
}

static inline long __syscall3(long n, long a, long b, long c)
{
	register long r1 __asm__("r1") = n;
	register long r2 __asm__("r2") = a;
	register long r3 __asm__("r3") = b;
	register long r4 __asm__("r4") = c;
	__asm_syscall("+r"(r2), "r"(r1), "r"(r3), "r"(r4));
}

static inline long __syscall4(long n, long a, long b, long c, long d)
{
	register long r1 __asm__("r1") = n;
	register long r2 __asm__("r2") = a;
	register long r3 __asm__("r3") = b;
	register long r4 __asm__("r4") = c;
	register long r5 __asm__("r5") = d;
	__asm_syscall("+r"(r2), "r"(r1), "r"(r3), "r"(r4), "r"(r5));
}

static inline long __syscall5(long n, long a, long b, long c, long d, long e)
{
	register long r1 __asm__("r1") = n;
	register long r2 __asm__("r2") = a;
	register long r3 __asm__("r3") = b;
	register long r4 __asm__("r4") = c;
	register long r5 __asm__("r5") = d;
	register long r6 __asm__("r6") = e;
	__asm_syscall("+r"(r2), "r"(r1), "r"(r3), "r"(r4), "r"(r5), "r"(r6));
}

static inline long __syscall6(long n, long a, long b, long c, long d, long e, long f)
{
	if (n == SYS_mmap) return __syscall1(n, (long)(long[]){a,b,c,d,e,f});

	register long r1 __asm__("r1") = n;
	register long r2 __asm__("r2") = a;
	register long r3 __asm__("r3") = b;
	register long r4 __asm__("r4") = c;
	register long r5 __asm__("r5") = d;
	register long r6 __asm__("r6") = e;
	register long r7 __asm__("r7") = f;
	__asm_syscall("+r"(r2), "r"(r1), "r"(r3), "r"(r4), "r"(r5), "r"(r6), "r"(r7));
}
