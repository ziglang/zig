#include "stdio_impl.h"
#include <wchar.h>

wint_t getwc(FILE *f)
{
	return fgetwc(f);
}
