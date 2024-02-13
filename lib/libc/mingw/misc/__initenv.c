/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <internal.h>

static char ** local__initenv;
static wchar_t ** local__winitenv;
char *** __MINGW_IMP_SYMBOL(__initenv) = &local__initenv;
wchar_t *** __MINGW_IMP_SYMBOL(__winitenv) = &local__winitenv;
