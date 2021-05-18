#define _BSD_SOURCE
#include <string.h>
#include <strings.h>

char *index(const char *s, int c)
{
	return strchr(s, c);
}
