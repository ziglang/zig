/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <windows.h>
#include <locale.h>
#include <msvcrt.h>

static _locale_t __cdecl init_func(int category, const char *locale);
_locale_t (__cdecl *__MINGW_IMP_SYMBOL(_create_locale))(int, const char *) = init_func;

static _locale_t __cdecl null_func(int category, const char *locale)
{
  (void)category;
  (void)locale;
  return NULL;
}

static _locale_t __cdecl init_func(int category, const char *locale)
{
    HMODULE msvcrt = __mingw_get_msvcrt_handle();
    _locale_t (__cdecl *func)(int, const char *) = NULL;

    if (msvcrt)
        func = (void*)GetProcAddress(msvcrt, "_create_locale");

    if (!func)
        func = null_func;

    return (__MINGW_IMP_SYMBOL(_create_locale) = func)(category, locale);
}
