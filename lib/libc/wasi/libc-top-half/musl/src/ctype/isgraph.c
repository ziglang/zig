#include <ctype.h>
#undef isgraph

int isgraph(int c)
{
	return (unsigned)c-0x21 < 0x5e;
}

int __isgraph_l(int c, locale_t l)
{
	return isgraph(c);
}

weak_alias(__isgraph_l, isgraph_l);
