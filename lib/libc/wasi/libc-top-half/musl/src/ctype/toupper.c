#include <ctype.h>

int toupper(int c)
{
	if (islower(c)) return c & 0x5f;
	return c;
}

int __toupper_l(int c, locale_t l)
{
	return toupper(c);
}

weak_alias(__toupper_l, toupper_l);
