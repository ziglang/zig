/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <crtdefs.h>
#include <internal.h>

_PGLOBAL
volatile unsigned int __native_dllmain_reason = UINT_MAX;
volatile unsigned int __native_vcclrit_reason = UINT_MAX;
volatile __enative_startup_state __native_startup_state;
volatile void *__native_startup_lock;
