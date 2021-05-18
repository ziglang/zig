#include <unistd.h>
#include "syscall.h"

void sync(void)
{
	__syscall(SYS_sync);
}
