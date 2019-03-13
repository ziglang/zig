#include <string.h>

char *strrchr(const char *s, int c)
{
	return __memrchr(s, c, strlen(s) + 1);
}
