#include "stdio_impl.h"
#include <wchar.h>

wint_t putwchar(wchar_t c)
{
	return fputwc(c, stdout);
}

weak_alias(putwchar, putwchar_unlocked);
