#define _GNU_SOURCE
#include <unistd.h>
#include "syscall.h"

int acct(const char *filename)
{
	return syscall(SYS_acct, filename);
}
