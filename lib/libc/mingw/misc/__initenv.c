/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <_mingw.h>

static char ** local__initenv;
char *** __MINGW_IMP_SYMBOL(__initenv) = &local__initenv;
