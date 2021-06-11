#define _GNU_SOURCE
#include <unistd.h>
#include <fcntl.h>

int euidaccess(const char *filename, int amode)
{
	return faccessat(AT_FDCWD, filename, amode, AT_EACCESS);
}

weak_alias(euidaccess, eaccess);
