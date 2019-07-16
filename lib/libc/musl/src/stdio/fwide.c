#include <wchar.h>
#include "stdio_impl.h"
#include "locale_impl.h"

int fwide(FILE *f, int mode)
{
	FLOCK(f);
	if (mode) {
		if (!f->locale) f->locale = MB_CUR_MAX==1
			? C_LOCALE : UTF8_LOCALE;
		if (!f->mode) f->mode = mode>0 ? 1 : -1;
	}
	mode = f->mode;
	FUNLOCK(f);
	return mode;
}
