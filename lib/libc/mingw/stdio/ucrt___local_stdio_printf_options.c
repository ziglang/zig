/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#undef __MSVCRT_VERSION__
#define _UCRT
#include <corecrt_stdio_config.h>

static unsigned __int64 options = _CRT_INTERNAL_PRINTF_LEGACY_WIDE_SPECIFIERS | _CRT_INTERNAL_PRINTF_STANDARD_ROUNDING;

unsigned __int64* __local_stdio_printf_options(void) {
  return &options;
}
