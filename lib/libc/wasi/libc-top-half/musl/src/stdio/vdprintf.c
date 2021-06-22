#include "stdio_impl.h"

int vdprintf(int fd, const char *restrict fmt, va_list ap)
{
	FILE f = {
		.fd = fd, .lbf = EOF, .write = __stdio_write,
		.buf = (void *)fmt, .buf_size = 0,
#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
		.lock = -1
#endif
	};
	return vfprintf(&f, fmt, ap);
}
