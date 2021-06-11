#include <ctype.h>
#undef isprint

int isprint(int c)
{
	return (unsigned)c-0x20 < 0x5f;
}

int __isprint_l(int c, locale_t l)
{
	return isprint(c);
}

weak_alias(__isprint_l, isprint_l);
