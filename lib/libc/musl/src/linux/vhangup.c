#define _GNU_SOURCE
#include <unistd.h>
#include "syscall.h"

int vhangup(void)
{
	return syscall(SYS_vhangup);
}
