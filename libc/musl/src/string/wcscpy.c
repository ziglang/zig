#include <wchar.h>

wchar_t *wcscpy(wchar_t *restrict d, const wchar_t *restrict s)
{
	wchar_t *a = d;
	while ((*d++ = *s++));
	return a;
}
