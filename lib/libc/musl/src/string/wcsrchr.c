#include <wchar.h>

wchar_t *wcsrchr(const wchar_t *s, wchar_t c)
{
	const wchar_t *p;
	for (p=s+wcslen(s); p>=s && *p!=c; p--);
	return p>=s ? (wchar_t *)p : 0;
}
