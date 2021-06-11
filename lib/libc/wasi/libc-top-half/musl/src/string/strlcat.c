#define _BSD_SOURCE
#include <string.h>

size_t strlcat(char *d, const char *s, size_t n)
{
	size_t l = strnlen(d, n);
	if (l == n) return l + strlen(s);
	return l + strlcpy(d+l, s, n-l);
}
