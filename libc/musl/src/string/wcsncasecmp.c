#include <wchar.h>
#include <wctype.h>

int wcsncasecmp(const wchar_t *l, const wchar_t *r, size_t n)
{
	if (!n--) return 0;
	for (; *l && *r && n && (*l == *r || towlower(*l) == towlower(*r)); l++, r++, n--);
	return towlower(*l) - towlower(*r);
}
