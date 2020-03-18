/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <assert.h>
#include <stdlib.h>
#include <windows.h>
#include "msvcrt.h"

/* _wassert is not available on XP, so forward it to _assert if needed */
static void __cdecl mingw_wassert(const wchar_t *_Message, const wchar_t *_File, unsigned _Line)
{
    char *message = NULL, *file = NULL;
    size_t len;

    if ((len = wcstombs(NULL, _Message, 0)) != (size_t)-1)
    {
        message = malloc(len + 1);
        wcstombs(message, _Message, len + 1);
    }

    if ((len = wcstombs(NULL, _File, 0)) != (size_t)-1)
    {
        file = malloc(len + 1);
        wcstombs(file, _File, len + 1);
    }

    _assert(message, file, _Line);

    free(message);
    free(file);
}

static void __cdecl init_wassert(const wchar_t *message, const wchar_t *file, unsigned line);

void (__cdecl *__MINGW_IMP_SYMBOL(_wassert))(const wchar_t*, const wchar_t*,unsigned) = init_wassert;

static void __cdecl init_wassert(const wchar_t *message, const wchar_t *file, unsigned line)
{
    void *func;

    func = (void*)GetProcAddress(__mingw_get_msvcrt_handle(), "_wassert");
    if(!func)
        func = mingw_wassert;

    return (__MINGW_IMP_SYMBOL(_wassert) = func)(message, file, line);
}
