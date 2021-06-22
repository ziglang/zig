#include <stdio.h>
#include "getc.h"

int getchar(void)
{
	return do_getc(stdin);
}
