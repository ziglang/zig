#define _GNU_SOURCE
#include <stdio.h>

void setbuffer(FILE *f, char *buf, size_t size)
{
	setvbuf(f, buf, buf ? _IOFBF : _IONBF, size);
}
