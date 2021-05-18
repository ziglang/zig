#include "syscall.h"
#ifdef SYS_arch_prctl
int arch_prctl(int code, unsigned long addr)
{
	return syscall(SYS_arch_prctl, code, addr);
}
#endif
