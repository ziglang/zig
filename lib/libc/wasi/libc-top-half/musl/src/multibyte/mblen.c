#include <stdlib.h>

int mblen(const char *s, size_t n)
{
	return mbtowc(0, s, n);
}
