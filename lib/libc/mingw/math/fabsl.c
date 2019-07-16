/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
long double fabsl (long double x);

long double
fabsl (long double x)
{
#if defined(__x86_64__) || defined(_AMD64_) || defined(__i386__) || defined(_X86_)
  long double res = 0.0L;
  asm volatile ("fabs;" : "=t" (res) : "0" (x));
  return res;
#elif defined(__arm__) || defined(_ARM_) || defined(__aarch64__) || defined(_ARM64_)
  return __builtin_fabsl (x);
#endif /* defined(__x86_64__) || defined(_AMD64_) || defined(__i386__) || defined(_X86_) */
}
