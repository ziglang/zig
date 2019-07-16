#include "stdio_impl.h"

/* This function assumes it will never be called if there is already
 * data buffered for reading. */

int __uflow(FILE *f)
{
	unsigned char c;
	if (!__toread(f) && f->read(f, &c, 1)==1) return c;
	return EOF;
}
