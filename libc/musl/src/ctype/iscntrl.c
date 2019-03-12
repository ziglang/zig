#include <ctype.h>

int iscntrl(int c)
{
	return (unsigned)c < 0x20 || c == 0x7f;
}

int __iscntrl_l(int c, locale_t l)
{
	return iscntrl(c);
}

weak_alias(__iscntrl_l, iscntrl_l);
