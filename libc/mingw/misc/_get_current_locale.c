#include <windows.h>
#include <locale.h>
#include <msvcrt.h>

static _locale_t __cdecl init_func(void);
_locale_t (__cdecl *__MINGW_IMP_SYMBOL(_get_current_locale))(void) = init_func;

static _locale_t __cdecl null_func(void)
{
  return NULL;
}

static _locale_t __cdecl init_func(void)
{
    HMODULE msvcrt = __mingw_get_msvcrt_handle();
    _locale_t (__cdecl *func)(void) = NULL;

    if (msvcrt) {
        func = (void*)GetProcAddress(msvcrt, "_get_current_locale");
    }

    if (!func)
        func = null_func;

    return (__MINGW_IMP_SYMBOL(_get_current_locale) = func)();
}
