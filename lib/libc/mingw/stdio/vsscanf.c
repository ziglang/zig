/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <stdarg.h>
#include <stdio.h>

extern int __ms_vsscanf_internal (
  const char * s,
  const char * format,
  va_list arg,
  int (*func)(const char * __restrict__,  const char * __restrict__, ...))
  asm("__argtos");

int __ms_vsscanf (const char * __restrict__ s,
  const char * __restrict__ format, va_list arg)
{
  int ret;

#if defined(_AMD64_) || defined(__x86_64__) || \
  defined(_X86_) || defined(__i386__) || \
  defined(_ARM_) || defined(__arm__) || \
  defined(_ARM64_) || defined(__aarch64__)
  ret = __ms_vsscanf_internal (s, format, arg, sscanf);
#else
#error "unknown platform"
#endif

  return ret;
}
