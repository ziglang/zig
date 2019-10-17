#define __SYSCALL_LL_E(x) (x)
#define __SYSCALL_LL_O(x) (x)

static inline long __syscall0(long n)
{
	register long r0 __asm__("r0") = n;
	register long r3 __asm__("r3");
	__asm__ __volatile__("sc ; bns+ 1f ; neg %1, %1 ; 1:"
	: "+r"(r0), "=r"(r3)
	:: "memory", "cr0", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12");
	return r3;
}

static inline long __syscall1(long n, long a)
{
	register long r0 __asm__("r0") = n;
	register long r3 __asm__("r3") = a;
	__asm__ __volatile__("sc ; bns+ 1f ; neg %1, %1 ; 1:"
	: "+r"(r0), "+r"(r3)
	:: "memory", "cr0", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12");
	return r3;
}

static inline long __syscall2(long n, long a, long b)
{
	register long r0 __asm__("r0") = n;
	register long r3 __asm__("r3") = a;
	register long r4 __asm__("r4") = b;
	__asm__ __volatile__("sc ; bns+ 1f ; neg %1, %1 ; 1:"
	: "+r"(r0), "+r"(r3), "+r"(r4)
	:: "memory", "cr0", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12");
	return r3;
}

static inline long __syscall3(long n, long a, long b, long c)
{
	register long r0 __asm__("r0") = n;
	register long r3 __asm__("r3") = a;
	register long r4 __asm__("r4") = b;
	register long r5 __asm__("r5") = c;
	__asm__ __volatile__("sc ; bns+ 1f ; neg %1, %1 ; 1:"
	: "+r"(r0), "+r"(r3), "+r"(r4), "+r"(r5)
	:: "memory", "cr0", "r6", "r7", "r8", "r9", "r10", "r11", "r12");
	return r3;
}

static inline long __syscall4(long n, long a, long b, long c, long d)
{
	register long r0 __asm__("r0") = n;
	register long r3 __asm__("r3") = a;
	register long r4 __asm__("r4") = b;
	register long r5 __asm__("r5") = c;
	register long r6 __asm__("r6") = d;
	__asm__ __volatile__("sc ; bns+ 1f ; neg %1, %1 ; 1:"
	: "+r"(r0), "+r"(r3), "+r"(r4), "+r"(r5), "+r"(r6)
	:: "memory", "cr0", "r7", "r8", "r9", "r10", "r11", "r12");
	return r3;
}

static inline long __syscall5(long n, long a, long b, long c, long d, long e)
{
	register long r0 __asm__("r0") = n;
	register long r3 __asm__("r3") = a;
	register long r4 __asm__("r4") = b;
	register long r5 __asm__("r5") = c;
	register long r6 __asm__("r6") = d;
	register long r7 __asm__("r7") = e;
	__asm__ __volatile__("sc ; bns+ 1f ; neg %1, %1 ; 1:"
	: "+r"(r0), "+r"(r3), "+r"(r4), "+r"(r5), "+r"(r6), "+r"(r7)
	:: "memory", "cr0", "r8", "r9", "r10", "r11", "r12");
	return r3;
}

static inline long __syscall6(long n, long a, long b, long c, long d, long e, long f)
{
	register long r0 __asm__("r0") = n;
	register long r3 __asm__("r3") = a;
	register long r4 __asm__("r4") = b;
	register long r5 __asm__("r5") = c;
	register long r6 __asm__("r6") = d;
	register long r7 __asm__("r7") = e;
	register long r8 __asm__("r8") = f;
	__asm__ __volatile__("sc ; bns+ 1f ; neg %1, %1 ; 1:"
	: "+r"(r0), "+r"(r3), "+r"(r4), "+r"(r5), "+r"(r6), "+r"(r7), "+r"(r8)
	:: "memory", "cr0", "r9", "r10", "r11", "r12");
	return r3;
}

#define SO_RCVTIMEO_OLD  18
#define SO_SNDTIMEO_OLD  19
