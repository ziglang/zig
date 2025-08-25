#include <unistd.h>
#include "syscall.h"

int pause(void)
{
#ifdef SYS_pause
	return syscall_cp(SYS_pause);
#else
	return syscall_cp(SYS_ppoll, 0, 0, 0, 0);
#endif
}
