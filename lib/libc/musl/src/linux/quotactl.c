#include <sys/quota.h>
#include "syscall.h"

int quotactl(int cmd, const char *special, int id, char *addr)
{
	return syscall(SYS_quotactl, cmd, special, id, addr);
}
