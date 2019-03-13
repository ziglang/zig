#include <wchar.h>

size_t wcsnlen(const wchar_t *s, size_t n)
{
	const wchar_t *z = wmemchr(s, 0, n);
	if (z) n = z-s;
	return n;
}
