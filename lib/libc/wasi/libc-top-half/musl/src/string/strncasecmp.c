#include <strings.h>
#include <ctype.h>

int strncasecmp(const char *_l, const char *_r, size_t n)
{
	const unsigned char *l=(void *)_l, *r=(void *)_r;
	if (!n--) return 0;
	for (; *l && *r && n && (*l == *r || tolower(*l) == tolower(*r)); l++, r++, n--);
	return tolower(*l) - tolower(*r);
}

int __strncasecmp_l(const char *l, const char *r, size_t n, locale_t loc)
{
	return strncasecmp(l, r, n);
}

weak_alias(__strncasecmp_l, strncasecmp_l);
