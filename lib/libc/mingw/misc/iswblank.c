#define _CRT_WCTYPE_NOINLINE
#include <ctype.h>

int __cdecl iswblank (wint_t _C)
{
  return (iswctype(_C, _BLANK) || _C == '\t');
}
