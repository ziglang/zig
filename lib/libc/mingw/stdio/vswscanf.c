/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <stdarg.h>
#include <wchar.h>

extern int __ms_vswscanf_internal (
  const wchar_t * s,
  const wchar_t * format,
  va_list arg,
  int (*func)(const wchar_t * __restrict__,  const wchar_t * __restrict__, ...))
  asm("__argtos");

int __ms_vswscanf(const wchar_t * __restrict__ s, const wchar_t * __restrict__ format,
  va_list arg)
{
  int ret;

#if defined(_AMD64_) || defined(__x86_64__) || \
  defined(_X86_) || defined(__i386__) || \
  defined(_ARM_) || defined(__arm__) || \
  defined(_ARM64_) || defined(__aarch64__)
  ret = __ms_vswscanf_internal (s, format, arg, swscanf);
#else
#error "unknown platform"
#endif

  return ret;
}
