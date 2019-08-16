#define __SYSCALL_LL_E(x) (x)
#define __SYSCALL_LL_O(x) (x)

#define SYSCALL_RLIM_INFINITY (-1UL/2)

#include <sys/stat.h>
struct kernel_stat {
	unsigned int st_dev;
	unsigned int __pad1[3];
	unsigned long long st_ino;
	unsigned int st_mode;
	unsigned int st_nlink;
	int st_uid;
	int st_gid;
	unsigned int st_rdev;
	unsigned int __pad2[3];
	long long st_size;
	unsigned int st_atime_sec;
	unsigned int st_atime_nsec;
	unsigned int st_mtime_sec;
	unsigned int st_mtime_nsec;
	unsigned int st_ctime_sec;
	unsigned int st_ctime_nsec;
	unsigned int st_blksize;
	unsigned int __pad3;
	unsigned long long st_blocks;
};

static void __stat_fix(struct kernel_stat *kst, struct stat *st)
{
	st->st_dev = kst->st_dev;
	st->st_ino = kst->st_ino;
	st->st_mode = kst->st_mode;
	st->st_nlink = kst->st_nlink;
	st->st_uid = kst->st_uid;
	st->st_gid = kst->st_gid;
	st->st_rdev = kst->st_rdev;
	st->st_size = kst->st_size;
	st->st_atim.tv_sec = kst->st_atime_sec;
	st->st_atim.tv_nsec = kst->st_atime_nsec;
	st->st_mtim.tv_sec = kst->st_mtime_sec;
	st->st_mtim.tv_nsec = kst->st_mtime_nsec;
	st->st_ctim.tv_sec = kst->st_ctime_sec;
	st->st_ctim.tv_nsec = kst->st_ctime_nsec;
	st->st_blksize = kst->st_blksize;
	st->st_blocks = kst->st_blocks;
}

static inline long __syscall0(long n)
{
	register long r7 __asm__("$7");
	register long r2 __asm__("$2");
	__asm__ __volatile__ (
		"daddu $2,$0,%2 ; syscall"
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
		"daddu $2,$0,%2 ; syscall"
		: "=&r"(r2), "=r"(r7) : "ir"(n), "0"(r2), "1"(r7),
		  "r"(r4)
		: "$1", "$3", "$8", "$9", "$10", "$11", "$12", "$13",
		  "$14", "$15", "$24", "$25", "hi", "lo", "memory");
	return r7 ? -r2 : r2;
}

static inline long __syscall2(long n, long a, long b)
{
	struct kernel_stat kst;
	long ret;
	register long r4 __asm__("$4") = a;
	register long r5 __asm__("$5") = b;
	register long r7 __asm__("$7");
	register long r2 __asm__("$2");

	if (n == SYS_stat || n == SYS_fstat || n == SYS_lstat)
		r5 = (long) &kst;

	__asm__ __volatile__ (
		"daddu $2,$0,%2 ; syscall"
		: "=&r"(r2), "=r"(r7) : "ir"(n), "0"(r2), "1"(r7),
		  "r"(r4), "r"(r5)
		: "$1", "$3", "$8", "$9", "$10", "$11", "$12", "$13",
		  "$14", "$15", "$24", "$25", "hi", "lo", "memory");

	if (r7) return -r2;
	ret = r2;

	if (n == SYS_stat || n == SYS_fstat || n == SYS_lstat)
		__stat_fix(&kst, (struct stat *)b);

	return ret;
}

static inline long __syscall3(long n, long a, long b, long c)
{
	struct kernel_stat kst;
	long ret;
	register long r4 __asm__("$4") = a;
	register long r5 __asm__("$5") = b;
	register long r6 __asm__("$6") = c;
	register long r7 __asm__("$7");
	register long r2 __asm__("$2");

	if (n == SYS_stat || n == SYS_fstat || n == SYS_lstat)
		r5 = (long) &kst;

	__asm__ __volatile__ (
		"daddu $2,$0,%2 ; syscall"
		: "=&r"(r2), "=r"(r7) : "ir"(n), "0"(r2), "1"(r7),
		  "r"(r4), "r"(r5), "r"(r6)
		: "$1", "$3", "$8", "$9", "$10", "$11", "$12", "$13",
		  "$14", "$15", "$24", "$25", "hi", "lo", "memory");

	if (r7) return -r2;
	ret = r2;

	if (n == SYS_stat || n == SYS_fstat || n == SYS_lstat)
		__stat_fix(&kst, (struct stat *)b);

	return ret;
}

static inline long __syscall4(long n, long a, long b, long c, long d)
{
	struct kernel_stat kst;
	long ret;
	register long r4 __asm__("$4") = a;
	register long r5 __asm__("$5") = b;
	register long r6 __asm__("$6") = c;
	register long r7 __asm__("$7") = d;
	register long r2 __asm__("$2");

	if (n == SYS_stat || n == SYS_fstat || n == SYS_lstat)
		r5 = (long) &kst;
	if (n == SYS_newfstatat)
		r6 = (long) &kst;

	__asm__ __volatile__ (
		"daddu $2,$0,%2 ; syscall"
		: "=&r"(r2), "=r"(r7) : "ir"(n), "0"(r2), "1"(r7),
		  "r"(r4), "r"(r5), "r"(r6)
		: "$1", "$3", "$8", "$9", "$10", "$11", "$12", "$13",
		  "$14", "$15", "$24", "$25", "hi", "lo", "memory");

	if (r7) return -r2;
	ret = r2;

	if (n == SYS_stat || n == SYS_fstat || n == SYS_lstat)
		__stat_fix(&kst, (struct stat *)b);
	if (n == SYS_newfstatat)
		__stat_fix(&kst, (struct stat *)c);

	return ret;
}

static inline long __syscall5(long n, long a, long b, long c, long d, long e)
{
	struct kernel_stat kst;
	long ret;
	register long r4 __asm__("$4") = a;
	register long r5 __asm__("$5") = b;
	register long r6 __asm__("$6") = c;
	register long r7 __asm__("$7") = d;
	register long r8 __asm__("$8") = e;
	register long r2 __asm__("$2");

	if (n == SYS_stat || n == SYS_fstat || n == SYS_lstat)
		r5 = (long) &kst;
	if (n == SYS_newfstatat)
		r6 = (long) &kst;

	__asm__ __volatile__ (
		"daddu $2,$0,%2 ; syscall"
		: "=&r"(r2), "=r"(r7) : "ir"(n), "0"(r2), "1"(r7),
		  "r"(r4), "r"(r5), "r"(r6), "r"(r8)
		: "$1", "$3", "$9", "$10", "$11", "$12", "$13",
		  "$14", "$15", "$24", "$25", "hi", "lo", "memory");

	if (r7) return -r2;
	ret = r2;

	if (n == SYS_stat || n == SYS_fstat || n == SYS_lstat)
		__stat_fix(&kst, (struct stat *)b);
	if (n == SYS_newfstatat)
		__stat_fix(&kst, (struct stat *)c);

	return ret;
}

static inline long __syscall6(long n, long a, long b, long c, long d, long e, long f)
{
	struct kernel_stat kst;
	long ret;
	register long r4 __asm__("$4") = a;
	register long r5 __asm__("$5") = b;
	register long r6 __asm__("$6") = c;
	register long r7 __asm__("$7") = d;
	register long r8 __asm__("$8") = e;
	register long r9 __asm__("$9") = f;
	register long r2 __asm__("$2");

	if (n == SYS_stat || n == SYS_fstat || n == SYS_lstat)
		r5 = (long) &kst;
	if (n == SYS_newfstatat)
		r6 = (long) &kst;

	__asm__ __volatile__ (
		"daddu $2,$0,%2 ; syscall"
		: "=&r"(r2), "=r"(r7) : "ir"(n), "0"(r2), "1"(r7),
		  "r"(r4), "r"(r5), "r"(r6), "r"(r8), "r"(r9)
		: "$1", "$3", "$10", "$11", "$12", "$13",
		  "$14", "$15", "$24", "$25", "hi", "lo", "memory");

	if (r7) return -r2;
	ret = r2;

	if (n == SYS_stat || n == SYS_fstat || n == SYS_lstat)
		__stat_fix(&kst, (struct stat *)b);
	if (n == SYS_newfstatat)
		__stat_fix(&kst, (struct stat *)c);

	return ret;
}

#define VDSO_USEFUL
#define VDSO_CGT_SYM "__vdso_clock_gettime"
#define VDSO_CGT_VER "LINUX_2.6"
