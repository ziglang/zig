#include <stdio.h>
#include <stdarg.h>
#include <wchar.h>

int fwscanf(FILE *restrict f, const wchar_t *restrict fmt, ...)
{
	int ret;
	va_list ap;
	va_start(ap, fmt);
	ret = vfwscanf(f, fmt, ap);
	va_end(ap);
	return ret;
}

weak_alias(fwscanf,__isoc99_fwscanf);
