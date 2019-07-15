/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <fenv.h> 

#if !(defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__))
extern int __mingw_has_sse (void);
#endif /* !(defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__)) */

/* 7.6.2.5 
   The fetestexcept function determines which of a specified subset of
   the exception flags are currently set. The excepts argument
   specifies the exception flags to be queried.
   The fetestexcept function returns the value of the bitwise OR of the
   exception macros corresponding to the currently set exceptions
   included in excepts. */

int fetestexcept (int excepts)
{
#if defined(_ARM_) || defined(__arm__)
  fenv_t _env;
  __asm__ volatile ("fmrx %0, FPSCR" : "=r" (_env));
  return _env.__cw & excepts & FE_ALL_EXCEPT;
#elif defined(_ARM64_) || defined(__aarch64__)
  unsigned __int64 fpcr;
  __asm__ volatile ("mrs %0, fpcr" : "=r" (fpcr));
  return fpcr & excepts & FE_ALL_EXCEPT;
#else
  unsigned short _sw;
  __asm__ __volatile__ ("fnstsw %%ax" : "=a" (_sw));

  if (__mingw_has_sse ())
    {
      int sse_sw;
      __asm__ __volatile__ ("stmxcsr %0;" : "=m" (sse_sw));
      _sw |= sse_sw;
    }
  return _sw & excepts & FE_ALL_EXCEPT;
#endif /* defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__) */
}
