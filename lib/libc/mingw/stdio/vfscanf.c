/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <stdio.h>
#include <stdarg.h>

extern int __ms_vfscanf_internal (
  FILE * s,
  const char * format,
  va_list arg,
  size_t count,
  int (*func)(FILE * __restrict__,  const char * __restrict__, ...))
  asm("__argtos");

extern size_t __ms_scanf_max_arg_count_internal (const char * format);

int __ms_vfscanf (FILE * __restrict__ stream, const char * __restrict__ format, va_list arg)
{
  size_t count = __ms_scanf_max_arg_count_internal (format);
  int ret;

#if defined(_AMD64_) || defined(__x86_64__) || \
  defined(_X86_) || defined(__i386__) || \
  defined(_ARM_) || defined(__arm__) || \
  defined(_ARM64_) || defined(__aarch64__)
  ret = __ms_vfscanf_internal (stream, format, arg, count, fscanf);
#else
#error "unknown platform"
#endif

  return ret;
}
