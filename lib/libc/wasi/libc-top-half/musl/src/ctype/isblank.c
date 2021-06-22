#include <ctype.h>

int isblank(int c)
{
	return (c == ' ' || c == '\t');
}

int __isblank_l(int c, locale_t l)
{
	return isblank(c);
}

weak_alias(__isblank_l, isblank_l);
