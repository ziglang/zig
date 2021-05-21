#ifdef __wasilibc_unmodified_upstream // WASI has no syscall
#else
#include <unistd.h>
#endif
#include "stdio_impl.h"
#include "stdio_impl.h"

off_t __stdio_seek(FILE *f, off_t off, int whence)
{
	return __lseek(f->fd, off, whence);
}
