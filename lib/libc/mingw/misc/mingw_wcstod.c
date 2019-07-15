#include <stdio.h>

extern long double __cdecl
__mingw_wcstold (const wchar_t * __restrict__ _Str, wchar_t ** __restrict__ _EndPtr);

double __cdecl
__mingw_wcstod (const wchar_t * __restrict__ _Str, wchar_t ** __restrict__ _EndPtr);

double __cdecl
__mingw_wcstod (const wchar_t * __restrict__ _Str, wchar_t ** __restrict__ _EndPtr)
{
  return (double) __mingw_wcstold (_Str, _EndPtr);
}


