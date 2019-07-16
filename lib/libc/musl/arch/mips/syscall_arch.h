#define __SYSCALL_LL_E(x) \
((union { long long ll; long l[2]; }){ .ll = x }).l[0], \
((union { long long ll; long l[2]; }){ .ll = x }).l[1]
#define __SYSCALL_LL_O(x) 0, __SYSCALL_LL_E((x))

hidden long (__syscall)(long, ...);

#define SYSCALL_RLIM_INFINITY (-1UL/2)

#if _MIPSEL || __MIPSEL || __MIPSEL__
#define __stat_fix(st) ((st),(void)0)
#else
#include <sys/stat.h>
static inline void __stat_fix(long p)
{
	struct stat *st = (struct stat *)p;
	st->st_dev >>= 32;
	st->st_rdev >>= 32;
}
#endif

static inline long __syscall0(long n)
{
	register long r7 __asm__("$7");
	register long r2 __asm__("$2");
	__asm__ __volatile__ (
		"addu $2,$0,%2 ; syscall"
		: "=&r"(r2), "=r"(r7) : "ir"(n), "0"(r2), "1"(r7)
		: "$1", "$3", "$8", "$9", "$10", "$11", "$12", "$13",
		  "$14", "$15", "$24", "$25", "hi", "lo", "memory");
	return r7 ? -r2 : r2;
}

static inline long __syscall1(long n, long a)
{
	register long r4 __asm__("$4") = a;
	register long r7 __asm__("$7");
	register long r2 __asm__("$2");
	__asm__ __volatile__ (
		"addu $2,$0,%2 ; syscall"
		: "=&r"(r2), "=r"(r7) : "ir"(n), "0"(r2), "1"(r7),
		  "r"(r4)
		: "$1", "$3", "$8", "$9", "$10", "$11", "$12", "$13",
		  "$14", "$15", "$24", "$25", "hi", "lo", "memory");
	return r7 ? -r2 : r2;
}

static inline long __syscall2(long n, long a, long b)
{
	register long r4 __asm__("$4") = a;
	register long r5 __asm__("$5") = b;
	register long r7 __asm__("$7");
	register long r2 __asm__("$2");
	__asm__ __volatile__ (
		"addu $2,$0,%2 ; syscall"
		: "=&r"(r2), "=r"(r7) : "ir"(n), "0"(r2), "1"(r7),
		  "r"(r4), "r"(r5)
		: "$1", "$3", "$8", "$9", "$10", "$11", "$12", "$13",
		  "$14", "$15", "$24", "$25", "hi", "lo", "memory");
	if (r7) return -r2;
	long ret = r2;
	if (n == SYS_stat64 || n == SYS_fstat64 || n == SYS_lstat64) __stat_fix(b);
	return ret;
}

static inline long __syscall3(long n, long a, long b, long c)
{
	register long r4 __asm__("$4") = a;
	register long r5 __asm__("$5") = b;
	register long r6 __asm__("$6") = c;
	register long r7 __asm__("$7");
	register long r2 __asm__("$2");
	__asm__ __volatile__ (
		"addu $2,$0,%2 ; syscall"
		: "=&r"(r2), "=r"(r7) : "ir"(n), "0"(r2), "1"(r7),
		  "r"(r4), "r"(r5), "r"(r6)
		: "$1", "$3", "$8", "$9", "$10", "$11", "$12", "$13",
		  "$14", "$15", "$24", "$25", "hi", "lo", "memory");
	if (r7) return -r2;
	long ret = r2;
	if (n == SYS_stat64 || n == SYS_fstat64 || n == SYS_lstat64) __stat_fix(b);
	return ret;
}

static inline long __syscall4(long n, long a, long b, long c, long d)
{
	register long r4 __asm__("$4") = a;
	register long r5 __asm__("$5") = b;
	register long r6 __asm__("$6") = c;
	register long r7 __asm__("$7") = d;
	register long r2 __asm__("$2");
	__asm__ __volatile__ (
		"addu $2,$0,%2 ; syscall"
		: "=&r"(r2), "=r"(r7) : "ir"(n), "0"(r2), "1"(r7),
		  "r"(r4), "r"(r5), "r"(r6)
		: "$1", "$3", "$8", "$9", "$10", "$11", "$12", "$13",
		  "$14", "$15", "$24", "$25", "hi", "lo", "memory");
	if (r7) return -r2;
	long ret = r2;
	if (n == SYS_stat64 || n == SYS_fstat64 || n == SYS_lstat64) __stat_fix(b);
	if (n == SYS_fstatat64) __stat_fix(c);
	return ret;
}

static inline long __syscall5(long n, long a, long b, long c, long d, long e)
{
	long r2 = (__syscall)(n, a, b, c, d, e);
	if (r2 > -4096UL) return r2;
	if (n == SYS_stat64 || n == SYS_fstat64 || n == SYS_lstat64) __stat_fix(b);
	if (n == SYS_fstatat64) __stat_fix(c);
	return r2;
}

static inline long __syscall6(long n, long a, long b, long c, long d, long e, long f)
{
	long r2 = (__syscall)(n, a, b, c, d, e, f);
	if (r2 > -4096UL) return r2;
	if (n == SYS_stat64 || n == SYS_fstat64 || n == SYS_lstat64) __stat_fix(b);
	if (n == SYS_fstatat64) __stat_fix(c);
	return r2;
}

#define VDSO_USEFUL
#define VDSO_CGT_SYM "__vdso_clock_gettime"
#define VDSO_CGT_VER "LINUX_2.6"
