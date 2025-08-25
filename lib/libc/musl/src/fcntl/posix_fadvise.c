#include <fcntl.h>
#include "syscall.h"

int posix_fadvise(int fd, off_t base, off_t len, int advice)
{
#if defined(SYSCALL_FADVISE_6_ARG)
	/* Some archs, at least arm and powerpc, have the syscall
	 * arguments reordered to avoid needing 7 argument registers
	 * due to 64-bit argument alignment. */
	return -__syscall(SYS_fadvise, fd, advice,
		__SYSCALL_LL_E(base), __SYSCALL_LL_E(len));
#else
	return -__syscall(SYS_fadvise, fd, __SYSCALL_LL_O(base),
		__SYSCALL_LL_E(len), advice);
#endif
}
