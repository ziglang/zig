/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <wchar.h>

wchar_t *__cdecl _wcstok(wchar_t *restrict str, const wchar_t *restrict delim)
{
  /* NULL as a third param can be specified only for UCRT version of wcstok() */
  return wcstok(str, delim, NULL);
}
wchar_t *(__cdecl *__MINGW_IMP_SYMBOL(_wcstok))(wchar_t *restrict, const wchar_t *restrict) = _wcstok;
