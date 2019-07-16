/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <stdlib.h>

char ***__cdecl __p___argv(void)
{
    return __MINGW_IMP_SYMBOL(__argv);
}

typedef char ***__cdecl (*_f__p___argv)(void);
_f__p___argv __MINGW_IMP_SYMBOL(__p___argv) = __p___argv;
