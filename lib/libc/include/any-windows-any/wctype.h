/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_WCTYPE
#define _INC_WCTYPE

#include <corecrt_wctype.h>

#ifdef __cplusplus
extern "C" {
#endif

  typedef wchar_t wctrans_t;
  wint_t __cdecl towctrans(wint_t,wctrans_t);
  wctrans_t __cdecl wctrans(const char *);
  wctype_t __cdecl wctype(const char *);

#ifdef __cplusplus
}
#endif

#endif
