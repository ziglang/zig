/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <fenv.h>
#include <math.h>
#include <errno.h>

long double
modfl (long double value, long double* iptr)
{
  long double int_part = 0.0L;
  /* truncate */
#if (defined(_AMD64_) && !defined(_ARM64EC_)) || (defined(__x86_64__) && !defined(__arm64ec__))
  asm volatile ("subq $8, %%rsp\n"
    "fnstcw 4(%%rsp)\n"
    "movzwl 4(%%rsp), %%eax\n"
    "orb $12, %%ah\n"
    "movw %%ax, (%%rsp)\n"
    "fldcw (%%rsp)\n"
    "frndint\n"
    "fldcw 4(%%rsp)\n"
    "addq $8, %%rsp\n" : "=t" (int_part) : "0" (value) : "eax"); /* round */
#elif defined(_X86_) || defined(__i386__)
  asm volatile ("push %%eax\n\tsubl $8, %%esp\n"
    "fnstcw 4(%%esp)\n"
    "movzwl 4(%%esp), %%eax\n"
    "orb $12, %%ah\n"
    "movw %%ax, (%%esp)\n"
    "fldcw (%%esp)\n"
    "frndint\n"
    "fldcw 4(%%esp)\n"
    "addl $8, %%esp\n\tpop %%eax\n" : "=t" (int_part) : "0" (value) : "eax"); /* round */
#else
  int_part = truncl(value);
#endif
  if (iptr)
    *iptr = int_part;
  return (isinf (value) ?  0.0L : value - int_part);
}
