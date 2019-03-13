#include <wchar.h>

size_t wcsspn(const wchar_t *s, const wchar_t *c)
{
	const wchar_t *a;
	for (a=s; *s && wcschr(c, *s); s++);
	return s-a;
}
