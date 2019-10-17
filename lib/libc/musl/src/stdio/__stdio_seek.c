#include "stdio_impl.h"
#include <unistd.h>

off_t __stdio_seek(FILE *f, off_t off, int whence)
{
	return __lseek(f->fd, off, whence);
}
