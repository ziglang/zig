#include <unistd.h>
#include "syscall.h"

off_t __lseek(int fd, off_t offset, int whence)
{
	register long long r4 __asm__("$4") = fd;
	register long long r5 __asm__("$5") = offset;
	register long long r6 __asm__("$6") = whence;
	register long long r7 __asm__("$7");
	register long long r2 __asm__("$2") = SYS_lseek;
	__asm__ __volatile__ (
		"syscall"
		: "+&r"(r2), "=r"(r7)
		: "r"(r4), "r"(r5), "r"(r6)
		: SYSCALL_CLOBBERLIST);
	return r7 ? __syscall_ret(-r2) : r2;
}

weak_alias(__lseek, lseek);
weak_alias(__lseek, lseek64);
