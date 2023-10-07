#define _BSD_SOURCE
#include <stdlib.h>

int mkstemps(char *template, int len)
{
	return __mkostemps(template, len, 0);
}
