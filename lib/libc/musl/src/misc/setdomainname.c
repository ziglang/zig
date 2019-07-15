#define _GNU_SOURCE
#include <unistd.h>
#include "syscall.h"

int setdomainname(const char *name, size_t len)
{
	return syscall(SYS_setdomainname, name, len);
}
