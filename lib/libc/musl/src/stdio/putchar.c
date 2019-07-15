#include <stdio.h>
#include "putc.h"

int putchar(int c)
{
	return do_putc(c, stdout);
}
