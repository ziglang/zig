#include <wchar.h>
#include <wctype.h>

int wcscasecmp(const wchar_t *l, const wchar_t *r)
{
	return wcsncasecmp(l, r, -1);
}
