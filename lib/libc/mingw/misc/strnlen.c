#define __CRT__NO_INLINE
#include <string.h>

size_t __cdecl strnlen (const char *s, size_t maxlen)
{
  const char *s2 = s;
  while ((size_t) (s2 - s) < maxlen && *s2)
    ++s2;
  return s2 - s;
}

