#include <time.h>

double __cdecl _difftime32(__time32_t _Time1,__time32_t _Time2)
{
  __time32_t r = _Time1 - _Time2;
  if (r > _Time1)
    return -((double) (_Time2 - _Time1));
  return (double) r;
}
