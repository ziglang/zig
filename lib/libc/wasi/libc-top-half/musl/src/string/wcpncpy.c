#include <wchar.h>

wchar_t *wcpncpy(wchar_t *restrict d, const wchar_t *restrict s, size_t n)
{
	return wcsncpy(d, s, n) + wcsnlen(s, n);
}
