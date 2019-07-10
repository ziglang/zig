/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <wchar.h>

extern wchar_t ** __MINGW_IMP_SYMBOL(_wcmdln);

wchar_t **__cdecl __p__wcmdln(void);
wchar_t **__cdecl __p__wcmdln(void)
{
    return __MINGW_IMP_SYMBOL(_wcmdln);
}

typedef wchar_t **__cdecl (*_f__p__wcmdln)(void);
_f__p__wcmdln __MINGW_IMP_SYMBOL(__p__wcmdln) = __p__wcmdln;
