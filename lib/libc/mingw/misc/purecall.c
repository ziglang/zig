/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#define _CRTIMP
#include <stdlib.h>
#include <windows.h>

_purecall_handler __cdecl _set_purecall_handler(_purecall_handler handler)
{
    static _purecall_handler prev_handler;
    return InterlockedExchangePointer((void**)&prev_handler, handler);
}

void *__MINGW_IMP_SYMBOL(_set_purecall_handler) = _set_purecall_handler;

