/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <_mingw.h>

extern int* __MINGW_IMP_SYMBOL(__mb_cur_max);

int __cdecl ___mb_cur_max_func(void);
int __cdecl ___mb_cur_max_func(void)
{
    return *__MINGW_IMP_SYMBOL(__mb_cur_max);
}

typedef int __cdecl (*_f___mb_cur_max_func)(void);
_f___mb_cur_max_func __MINGW_IMP_SYMBOL(___mb_cur_max_func) = ___mb_cur_max_func;
