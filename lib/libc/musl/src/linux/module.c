#include "syscall.h"

int init_module(void *a, unsigned long b, const char *c)
{
	return syscall(SYS_init_module, a, b, c);
}

int delete_module(const char *a, unsigned b)
{
	return syscall(SYS_delete_module, a, b);
}
