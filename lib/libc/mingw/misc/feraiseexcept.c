/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <fenv.h> 

/* 7.6.2.3
   The feraiseexcept function raises the supported exceptions
   represented by its argument The order in which these exceptions
   are raised is unspecified, except as stated in F.7.6.
   Whether the feraiseexcept function additionally raises
   the inexact exception whenever it raises the overflow
   or underflow exception is implementation-defined. */

int feraiseexcept (int excepts)
{
  fenv_t _env;
#if defined(_ARM_) || defined(__arm__)
  __asm__ volatile ("fmrx %0, FPSCR" : "=r" (_env));
  _env.__cw |= excepts & FE_ALL_EXCEPT;
  __asm__ volatile ("fmxr FPSCR, %0" : : "r" (_env));
#elif defined(_ARM64_) || defined(__aarch64__)
  unsigned __int64 fpcr;
  (void) _env;
  __asm__ volatile ("mrs %0, fpcr" : "=r" (fpcr));
  fpcr |= excepts & FE_ALL_EXCEPT;
  __asm__ volatile ("msr fpcr, %0" : : "r" (fpcr));
#else
  __asm__ volatile ("fnstenv %0;" : "=m" (_env));
  _env.__status_word |= excepts & FE_ALL_EXCEPT;
  __asm__ volatile ("fldenv %0;"
		    "fwait;" : : "m" (_env));
#endif /* defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__) */
  return 0;
}
