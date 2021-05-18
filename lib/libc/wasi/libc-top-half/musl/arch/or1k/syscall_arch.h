#define __SYSCALL_LL_E(x) \
((union { long long ll; long l[2]; }){ .ll = x }).l[0], \
((union { long long ll; long l[2]; }){ .ll = x }).l[1]
#define __SYSCALL_LL_O(x) __SYSCALL_LL_E((x))

#define SYSCALL_MMAP2_UNIT 8192ULL

static __inline long __syscall0(long n)
{
	register unsigned long r11 __asm__("r11") = n;
	__asm__ __volatile__ ("l.sys 1"
			      : "=r"(r11)
			      : "r"(r11)
			      : "memory", "r3", "r4", "r5", "r6", "r7", "r8",
				"r12", "r13", "r15", "r17", "r19", "r21",
				"r23", "r25", "r27", "r29", "r31");
	return r11;
}

static inline long __syscall1(long n, long a)
{
	register unsigned long r11 __asm__("r11") = n;
	register unsigned long r3 __asm__("r3") = a;
	__asm__ __volatile__ ("l.sys 1"
			      : "=r"(r11)
			      : "r"(r11), "r"(r3)
			      : "memory", "r4", "r5", "r6", "r7", "r8",
				"r12", "r13", "r15", "r17", "r19", "r21",
				"r23", "r25", "r27", "r29", "r31");
	return r11;
}

static inline long __syscall2(long n, long a, long b)
{
	register unsigned long r11 __asm__("r11") = n;
	register unsigned long r3 __asm__("r3") = a;
	register unsigned long r4 __asm__("r4") = b;
	__asm__ __volatile__ ("l.sys 1"
			      : "=r"(r11)
			      : "r"(r11), "r"(r3), "r"(r4)
			      : "memory", "r5", "r6", "r7", "r8",
				"r12", "r13", "r15", "r17", "r19", "r21",
				"r23", "r25", "r27", "r29", "r31");
	return r11;
}

static inline long __syscall3(long n, long a, long b, long c)
{
	register unsigned long r11 __asm__("r11") = n;
	register unsigned long r3 __asm__("r3") = a;
	register unsigned long r4 __asm__("r4") = b;
	register unsigned long r5 __asm__("r5") = c;
	__asm__ __volatile__ ("l.sys 1"
			      : "=r"(r11)
			      : "r"(r11), "r"(r3), "r"(r4), "r"(r5)
			      : "memory", "r6", "r7", "r8",
				"r12", "r13", "r15", "r17", "r19", "r21",
				"r23", "r25", "r27", "r29", "r31");
	return r11;
}

static inline long __syscall4(long n, long a, long b, long c, long d)
{
	register unsigned long r11 __asm__("r11") = n;
	register unsigned long r3 __asm__("r3") = a;
	register unsigned long r4 __asm__("r4") = b;
	register unsigned long r5 __asm__("r5") = c;
	register unsigned long r6 __asm__("r6") = d;
	__asm__ __volatile__ ("l.sys 1"
			      : "=r"(r11)
			      : "r"(r11), "r"(r3), "r"(r4), "r"(r5), "r"(r6)
			      : "memory", "r7", "r8",
				"r12", "r13", "r15", "r17", "r19", "r21",
				"r23", "r25", "r27", "r29", "r31");
	return r11;
}

static inline long __syscall5(long n, long a, long b, long c, long d, long e)
{
	register unsigned long r11 __asm__("r11") = n;
	register unsigned long r3 __asm__("r3") = a;
	register unsigned long r4 __asm__("r4") = b;
	register unsigned long r5 __asm__("r5") = c;
	register unsigned long r6 __asm__("r6") = d;
	register unsigned long r7 __asm__("r7") = e;
	__asm__ __volatile__ ("l.sys 1"
			      : "=r"(r11)
			      : "r"(r11), "r"(r3), "r"(r4), "r"(r5), "r"(r6),
				"r"(r7)
			      : "memory", "r8",
				"r12", "r13", "r15", "r17", "r19", "r21",
				"r23", "r25", "r27", "r29", "r31");
	return r11;
}

static inline long __syscall6(long n, long a, long b, long c, long d, long e, long f)
{
	register unsigned long r11 __asm__("r11") = n;
	register unsigned long r3 __asm__("r3") = a;
	register unsigned long r4 __asm__("r4") = b;
	register unsigned long r5 __asm__("r5") = c;
	register unsigned long r6 __asm__("r6") = d;
	register unsigned long r7 __asm__("r7") = e;
	register unsigned long r8 __asm__("r8") = f;
	__asm__ __volatile__ ("l.sys 1"
			      : "=r"(r11)
			      : "r"(r11), "r"(r3), "r"(r4), "r"(r5), "r"(r6),
				"r"(r7), "r"(r8)
			      : "memory",
				"r12", "r13", "r15", "r17", "r19", "r21",
				"r23", "r25", "r27", "r29", "r31");
	return r11;
}

#define IPC_64 0
