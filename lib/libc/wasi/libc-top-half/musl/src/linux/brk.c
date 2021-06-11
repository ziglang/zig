#define _BSD_SOURCE
#include <unistd.h>
#include <errno.h>
#include "syscall.h"

int brk(void *end)
{
	return __syscall_ret(-ENOMEM);
}
