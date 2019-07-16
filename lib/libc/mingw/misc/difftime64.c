#include <time.h>

double __cdecl _difftime64(__time64_t _Time1,__time64_t _Time2)
{
  __time64_t r = _Time1 - _Time2;
  if (r > _Time1)
    return -((double) (_Time2 - _Time1));
  return (double) r;
}
