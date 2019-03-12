#include <unistd.h>
#include "syscall.h"

uid_t geteuid(void)
{
	return __syscall(SYS_geteuid);
}
