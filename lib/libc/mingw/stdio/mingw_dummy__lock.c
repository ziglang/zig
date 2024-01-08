/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <internal.h>

void __cdecl _lock(int locknum);
void __cdecl _unlock(int locknum);
void __cdecl _lock(__UNUSED_PARAM(int locknum)) { }
void __cdecl _unlock(__UNUSED_PARAM(int locknum)) { }
