/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <windows.h>
#include <locale.h>
#include <msvcrt.h>

static void __cdecl init_func(_locale_t locale);
void (__cdecl *__MINGW_IMP_SYMBOL(_free_locale))(_locale_t) = init_func;

static void __cdecl stub_func(_locale_t locale)
{
  (void)locale;
}

static void __cdecl init_func(_locale_t locale)
{
    HMODULE msvcrt = __mingw_get_msvcrt_handle();
    void (__cdecl *func)(_locale_t) = NULL;

    if (msvcrt)
        func = (void*)GetProcAddress(msvcrt, "_free_locale");

    if (!func)
        func = stub_func;

    (__MINGW_IMP_SYMBOL(_free_locale) = func)(locale);
}
