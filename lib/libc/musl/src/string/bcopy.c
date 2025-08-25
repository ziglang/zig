#define _BSD_SOURCE
#include <string.h>
#include <strings.h>

void bcopy(const void *s1, void *s2, size_t n)
{
	memmove(s2, s1, n);
}
