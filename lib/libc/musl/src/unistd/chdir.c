#include <unistd.h>
#include "syscall.h"

int chdir(const char *path)
{
	return syscall(SYS_chdir, path);
}
