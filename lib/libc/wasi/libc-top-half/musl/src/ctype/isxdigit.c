#include <ctype.h>

int isxdigit(int c)
{
	return isdigit(c) || ((unsigned)c|32)-'a' < 6;
}

int __isxdigit_l(int c, locale_t l)
{
	return isxdigit(c);
}

weak_alias(__isxdigit_l, isxdigit_l);
