#include "stdio_impl.h"
#include "locale_impl.h"
#include <wchar.h>

int fputws(const wchar_t *restrict ws, FILE *restrict f)
{
	unsigned char buf[BUFSIZ];
	size_t l=0;
	locale_t *ploc = &CURRENT_LOCALE, loc = *ploc;

	FLOCK(f);

	fwide(f, 1);
	*ploc = f->locale;

	while (ws && (l = wcsrtombs((void *)buf, (void*)&ws, sizeof buf, 0))+1 > 1)
		if (__fwritex(buf, l, f) < l) {
			FUNLOCK(f);
			*ploc = loc;
			return -1;
		}

	FUNLOCK(f);

	*ploc = loc;
	return l; /* 0 or -1 */
}

weak_alias(fputws, fputws_unlocked);
