#include <wchar.h>

wchar_t *wmemset(wchar_t *d, wchar_t c, size_t n)
{
	wchar_t *ret = d;
	while (n--) *d++ = c;
	return ret;
}
