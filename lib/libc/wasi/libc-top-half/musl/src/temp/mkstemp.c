#include <stdlib.h>

int mkstemp(char *template)
{
	return __mkostemps(template, 0, 0);
}

weak_alias(mkstemp, mkstemp64);
