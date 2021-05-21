#include <ctype.h>
#undef isspace

int isspace(int c)
{
	return c == ' ' || (unsigned)c-'\t' < 5;
}

int __isspace_l(int c, locale_t l)
{
	return isspace(c);
}

weak_alias(__isspace_l, isspace_l);
