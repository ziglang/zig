#define __lc_codepage __dummy_lc_codepage
#define ___lc_codepage_func __dummy____lc_codepage_func
#include <windows.h>
#include <locale.h>

#undef __lc_codepage
#undef ___lc_codepage_func
#include "mb_wc_common.h"

static unsigned int __cdecl setlocale_codepage_hack(void)
{
    /* locale :: "lang[_country[.code_page]]" | ".code_page"  */
    const char *cp_str = strchr (setlocale(LC_CTYPE, NULL), '.');
    return cp_str ? atoi(cp_str + 1) : 0;
}

#ifndef __LIBMSVCRT_OS__

unsigned int (__cdecl *__MINGW_IMP_SYMBOL(___lc_codepage_func))(void) = setlocale_codepage_hack;

#else

#include <msvcrt.h>

static unsigned int *msvcrt__lc_codepage;
static unsigned int __cdecl msvcrt___lc_codepage_func(void)
{
    return *msvcrt__lc_codepage;
}

static unsigned int __cdecl init_codepage_func(void);
unsigned int (__cdecl *__MINGW_IMP_SYMBOL(___lc_codepage_func))(void) = init_codepage_func;

static unsigned int __cdecl init_codepage_func(void)
{
    HMODULE msvcrt = __mingw_get_msvcrt_handle();
    unsigned int (__cdecl *func)(void) = NULL;

    if(msvcrt) {
        func = (void*)GetProcAddress(msvcrt, "___lc_codepage_func");
        if(!func) {
            msvcrt__lc_codepage = (unsigned int*)GetProcAddress(msvcrt, "__lc_codepage");
            if(msvcrt__lc_codepage)
                func = msvcrt___lc_codepage_func;
        }
    }

    if(!func)
        func = setlocale_codepage_hack;

    return (__MINGW_IMP_SYMBOL(___lc_codepage_func) = func)();
}

#endif

unsigned int __cdecl ___lc_codepage_func(void)
{
    return __MINGW_IMP_SYMBOL(___lc_codepage_func)();
}
