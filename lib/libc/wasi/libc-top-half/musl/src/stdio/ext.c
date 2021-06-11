#define _GNU_SOURCE
#include "stdio_impl.h"
#include <stdio_ext.h>

void _flushlbf(void)
{
	fflush(0);
}

int __fsetlocking(FILE *f, int type)
{
	return 0;
}

int __fwriting(FILE *f)
{
	return (f->flags & F_NORD) || f->wend;
}

int __freading(FILE *f)
{
	return (f->flags & F_NOWR) || f->rend;
}

int __freadable(FILE *f)
{
	return !(f->flags & F_NORD);
}

int __fwritable(FILE *f)
{
	return !(f->flags & F_NOWR);
}

int __flbf(FILE *f)
{
	return f->lbf >= 0;
}

size_t __fbufsize(FILE *f)
{
	return f->buf_size;
}

size_t __fpending(FILE *f)
{
	return f->wend ? f->wpos - f->wbase : 0;
}

int __fpurge(FILE *f)
{
	f->wpos = f->wbase = f->wend = 0;
	f->rpos = f->rend = 0;
	return 0;
}

weak_alias(__fpurge, fpurge);
