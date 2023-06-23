#define _BSD_SOURCE
#include <stdlib.h>

int mkostemp(char *template, int flags)
{
	return __mkostemps(template, 0, flags);
}
