#include <windows.h>
#include <stdio.h>

float __cdecl
__mingw_wcstof (const wchar_t * __restrict__ _Str, wchar_t ** __restrict__ _EndPtr);

float __cdecl
__mingw_wcstof (const wchar_t * __restrict__ _Str, wchar_t ** __restrict__ _EndPtr)
{
  float r;
  char *n, *ep = NULL;
  size_t l, l2;

  l = WideCharToMultiByte(CP_UTF8, 0, _Str, -1, NULL, 0, NULL, NULL);
  n = alloca (l + 1);
  if (l != 0) WideCharToMultiByte (CP_UTF8, 0, _Str, -1, n, l, NULL, NULL);
  n[l] = 0;
  r = __mingw_strtof (n, &ep);  
  if (ep != NULL)
  {
    *ep = 0;
    l2 = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, n, -1, NULL, 0);
    if (l2 > 0)
      l2 -= 1; /* Remove zero terminator from length.  */
    if (_EndPtr) *_EndPtr = (wchar_t *) &_Str[l2];
  }
  else
   if (_EndPtr) *_EndPtr = NULL;
  return r;
}

