#include <wchar.h>

wchar_t *wcsncat(wchar_t *restrict d, const wchar_t *restrict s, size_t n)
{
	wchar_t *a = d;
	d += wcslen(d);
	while (n && *s) n--, *d++ = *s++;
	*d++ = 0;
	return a;
}
