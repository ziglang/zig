#define __CRT__NO_INLINE
#include <wchar.h>

wchar_t * __cdecl
wmempcpy (wchar_t *d, const wchar_t *s, size_t len)
{
  wchar_t *r = d + len;
  if (len != 0)
    memcpy (d, s, len * sizeof (wchar_t));
  return r;
}

