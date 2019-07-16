#include <wchar.h>

wchar_t *wcschr(const wchar_t *s, wchar_t c)
{
	if (!c) return (wchar_t *)s + wcslen(s);
	for (; *s && *s != c; s++);
	return *s ? (wchar_t *)s : 0;
}
