#include "stdio_impl.h"

int (putc_unlocked)(int c, FILE *f)
{
	return putc_unlocked(c, f);
}

weak_alias(putc_unlocked, fputc_unlocked);
weak_alias(putc_unlocked, _IO_putc_unlocked);
