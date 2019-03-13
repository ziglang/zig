#define _GNU_SOURCE
#include <stdio.h>

void setlinebuf(FILE *f)
{
	setvbuf(f, 0, _IOLBF, 0);
}
