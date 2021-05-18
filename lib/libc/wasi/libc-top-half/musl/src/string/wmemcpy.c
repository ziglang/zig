#include <wchar.h>

wchar_t *wmemcpy(wchar_t *restrict d, const wchar_t *restrict s, size_t n)
{
	wchar_t *a = d;
	while (n--) *d++ = *s++;
	return a;
}
