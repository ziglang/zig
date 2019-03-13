#include <wchar.h>

wchar_t *wcspbrk(const wchar_t *s, const wchar_t *b)
{
	s += wcscspn(s, b);
	return *s ? (wchar_t *)s : NULL;
}
