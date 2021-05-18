#include <ctype.h>
#undef isascii

int isascii(int c)
{
	return !(c&~0x7f);
}
