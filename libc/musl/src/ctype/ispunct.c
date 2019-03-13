#include <ctype.h>

int ispunct(int c)
{
	return isgraph(c) && !isalnum(c);
}

int __ispunct_l(int c, locale_t l)
{
	return ispunct(c);
}

weak_alias(__ispunct_l, ispunct_l);
