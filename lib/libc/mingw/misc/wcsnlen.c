#define __CRT__NO_INLINE
#include <string.h>

size_t __cdecl
wcsnlen(const wchar_t *w, size_t ncnt)
{
  size_t n = 0;

  for (; n < ncnt && *w != 0; n++, w++)
    ;

  return n;
}
