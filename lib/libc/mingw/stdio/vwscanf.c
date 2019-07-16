/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
//  By aaronwl 2003-01-28 for mingw-msvcrt.
//  Public domain: all copyrights disclaimed, absolutely no warranties.

#include <stdarg.h>
#include <wchar.h>
#include <stdio.h>

int __ms_vwscanf (const wchar_t * __restrict__ format, va_list arg)
{
  return __ms_vfwscanf(stdin, format, arg);
}
