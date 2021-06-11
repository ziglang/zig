#include "syscall.h"

#ifdef SYS_ioperm
#include <sys/io.h>

int ioperm(unsigned long from, unsigned long num, int turn_on)
{
	return syscall(SYS_ioperm, from, num, turn_on);
}
#endif
