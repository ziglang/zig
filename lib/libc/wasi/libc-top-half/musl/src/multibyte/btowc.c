#include <stdio.h>
#include <wchar.h>
#include <stdlib.h>
#include "internal.h"

wint_t btowc(int c)
{
	int b = (unsigned char)c;
	return b<128U ? b : (MB_CUR_MAX==1 && c!=EOF) ? CODEUNIT(c) : WEOF;
}
