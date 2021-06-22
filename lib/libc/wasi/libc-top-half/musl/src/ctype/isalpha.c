#include <ctype.h>
#undef isalpha

int isalpha(int c)
{
	return ((unsigned)c|32)-'a' < 26;
}

int __isalpha_l(int c, locale_t l)
{
	return isalpha(c);
}

weak_alias(__isalpha_l, isalpha_l);
