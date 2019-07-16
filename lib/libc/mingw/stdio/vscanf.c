/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
//  By aaronwl 2003-01-28 for mingw-msvcrt
//  Public domain: all copyrights disclaimed, absolutely no warranties

#include <stdarg.h>
#include <stdio.h>

int __ms_vscanf(const char * __restrict__ format, va_list arg)
{
  return __ms_vfscanf(stdin, format, arg);
}
